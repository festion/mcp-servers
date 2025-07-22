"""The Winix Air Purifier component."""

from __future__ import annotations

from collections.abc import Iterable
from typing import Final

from awesomeversion import AwesomeVersion
from winix import auth

from homeassistant.components import persistent_notification
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import (
    CONF_PASSWORD,
    CONF_USERNAME,
    STATE_UNAVAILABLE,
    Platform,
    __version__,
)
from homeassistant.core import HomeAssistant, ServiceCall, callback
from homeassistant.exceptions import ConfigEntryAuthFailed, ConfigEntryNotReady
from homeassistant.helpers import device_registry as dr, entity_registry as er

from .const import (
    FAN_SERVICES,
    LOGGER,
    SERVICE_REMOVE_STALE_ENTITIES,
    WINIX_AUTH_RESPONSE,
    WINIX_DATA_COORDINATOR,
    WINIX_DOMAIN,
    WINIX_NAME,
    __min_ha_version__,
)
from .helpers import Helpers, WinixException
from .manager import WinixManager

SUPPORTED_PLATFORMS = [Platform.FAN, Platform.SENSOR, Platform.SELECT, Platform.SWITCH]
DEFAULT_SCAN_INTERVAL: Final = 30


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up the Winix component."""

    if not is_valid_ha_version():
        msg = (
            "This integration require at least HomeAssistant version "
            f" {__min_ha_version__}, you are running version {__version__}."
            " Please upgrade HomeAssistant to continue use this integration."
        )

        LOGGER.warning(msg)
        persistent_notification.async_create(
            hass, msg, WINIX_NAME, f"{WINIX_DOMAIN}.inv_ha_version"
        )
        return False

    hass.data.setdefault(WINIX_DOMAIN, {})
    user_input = entry.data

    auth_response_data = user_input.get(WINIX_AUTH_RESPONSE)
    auth_response = (
        auth_response_data
        if isinstance(auth_response_data, auth.WinixAuthResponse)
        else auth.WinixAuthResponse(**auth_response_data)
    )

    if not auth_response:
        raise ConfigEntryAuthFailed(
            "No authentication data found. Please reconfigure the integration."
        )

    manager = WinixManager(hass, entry, auth_response, DEFAULT_SCAN_INTERVAL)

    new_auth_response = await hass.async_add_executor_job(
        prepare_devices,
        manager,
        user_input[CONF_USERNAME],
        user_input[CONF_PASSWORD],
    )
    if new_auth_response is not None:
        # Copy over new values
        LOGGER.debug(
            "access_token %s",
            "changed"
            if auth_response.access_token != new_auth_response.access_token
            else "unchanged",
        )
        LOGGER.debug(
            "refresh_token %s",
            "changed"
            if auth_response.refresh_token != new_auth_response.refresh_token
            else "unchanged",
        )
        LOGGER.debug(
            "id_token %s",
            "changed"
            if auth_response.id_token != new_auth_response.id_token
            else "unchanged",
        )

        auth_response.access_token = new_auth_response.access_token
        auth_response.refresh_token = new_auth_response.refresh_token
        auth_response.id_token = new_auth_response.id_token

        # Update tokens into entry.data
        hass.config_entries.async_update_entry(
            entry,
            data={**user_input, WINIX_AUTH_RESPONSE: auth_response},
        )

    await manager.async_config_entry_first_refresh()

    hass.data[WINIX_DOMAIN][entry.entry_id] = {WINIX_DATA_COORDINATOR: manager}
    await hass.config_entries.async_forward_entry_setups(entry, SUPPORTED_PLATFORMS)

    setup_hass_services(hass)
    return True


def prepare_devices(
    manager: WinixManager, username: str, password: str
) -> auth.WinixAuthResponse | None:
    """Prepare devices synchronously. Returns new auth response if re-login was needed.

    Raises ConfigEntryAuthFailed or ConfigEntryNotReady.
    """
    new_auth_response: auth.WinixAuthResponse = None

    try:
        manager.prepare_devices_wrappers()
    except WinixException as err:
        # 900:MULTI LOGIN: Same credentials were used to login elwsewhere. We need to
        # login again and get new tokens.
        # 400:The user is not valid.

        if err.result_code in ("900", "400"):
            LOGGER.info(
                f"Failed to get device list (code={err.result_code}, message={err.result_message}), reauthenticating with stored credentials"
            )

            try:
                new_auth_response = Helpers.login(username, password)
            except WinixException as login_err:
                raise ConfigEntryAuthFailed("Unable to authenticate.") from login_err

            LOGGER.info("Reauthenticating successful, getting device list again")

            # Try preparing device wrappers again with new auth response
            try:
                manager.prepare_devices_wrappers(new_auth_response.access_token)
            except WinixException as err_retry:
                raise ConfigEntryAuthFailed(
                    "Unable to access device data even after re-login."
                ) from err_retry

        else:
            raise ConfigEntryNotReady("Unable to access device data.") from err

    return new_auth_response


def setup_hass_services(hass: HomeAssistant) -> None:
    """Home Assistant services."""

    def remove_stale_entities(call: ServiceCall) -> None:
        """Remove stale entities."""
        device_registry = dr.async_get(hass)
        entity_registry = er.async_get(hass)

        # Using set to avoid duplicates
        entity_ids = set()
        device_ids = set()

        for state in hass.states.async_all(SUPPORTED_PLATFORMS):
            entity_id = state.entity_id
            entity = entity_registry.async_get(entity_id)

            if entity.unique_id.startswith(f"{entity.domain}.{WINIX_DOMAIN}_"):
                device_id = entity.device_id
                device = device_registry.async_get(device_id)

                if state.state == STATE_UNAVAILABLE or not device:
                    entity_ids.add(entity_id)
                    device_ids.add(device_id)

        if entity_ids:
            hass.add_job(
                async_remove, entity_registry, device_registry, entity_ids, device_ids
            )
        else:
            LOGGER.debug("Nothing to remove")

    hass.services.async_register(
        WINIX_DOMAIN, SERVICE_REMOVE_STALE_ENTITIES, remove_stale_entities
    )


@callback
def async_remove(
    entity_registry: er.EntityRegistry,
    device_registry: dr.DeviceRegistry,
    entity_ids: Iterable[str],
    device_ids: Iterable[str],
) -> None:
    """Remove devices and entities."""
    for entity_id in entity_ids:
        entity_registry.async_remove(entity_id)
        LOGGER.debug("Removing entity %s", entity_id)

    for device_id in device_ids:
        device_registry.async_remove_device(device_id)
        LOGGER.debug("Removing device %s", device_id)


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Unload a config entry."""
    unload_ok = await hass.config_entries.async_unload_platforms(
        entry, SUPPORTED_PLATFORMS
    )
    if unload_ok:
        hass.data.pop(WINIX_DOMAIN)

    other_loaded_entries = [
        _entry
        for _entry in hass.config_entries.async_loaded_entries(WINIX_DOMAIN)
        if _entry.entry_id != entry.entry_id
    ]
    if not other_loaded_entries:
        # If this is the last loaded instance, then unregister services
        hass.services.async_remove(WINIX_DOMAIN, SERVICE_REMOVE_STALE_ENTITIES)

        for service_name in FAN_SERVICES:
            hass.services.async_remove(WINIX_DOMAIN, service_name)

    return unload_ok


def is_valid_ha_version() -> bool:
    """Check if HA version is valid for this integration."""
    return AwesomeVersion(__version__) >= AwesomeVersion(__min_ha_version__)
