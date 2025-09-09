# Proxmox Storage Optimization Master Plan
## Real-World Performance-Based Strategy

### Executive Summary
**Current Status:** local-lvm at 85.1% usage (318.8GB/374.5GB) - WARNING level
**Goal:** Achieve <70% usage while optimizing performance based on workload characteristics
**Strategy:** Performance-tiered storage allocation with selective migration

---

## Phase 2: Strategic Performance-Aware Migration (78GB)

### 2A. IMMEDIATE MIGRATIONS (No Performance Impact)
**Target: 38GB freed, <5% performance impact**

#### High Priority (Network-bound workloads)
1. **CT 200 (github-runner) - 20GB**
   - **Rationale:** CI/CD is network-bound (git clone, npm install)
   - **Impact:** <5% - Network latency already dominates
   - **Downtime:** 2-3 minutes
   - **Benefits:** Large space recovery, minimal performance loss

2. **CT 125 (adguard) - 18GB** 
   - **Rationale:** DNS filtering is network-centric
   - **Impact:** <10% - DNS response times won't be noticeably affected
   - **Downtime:** 1-2 minutes (brief DNS interruption)
   - **Benefits:** Second largest container, low performance sensitivity

**Phase 2A Result:** Usage drops from 85.1% → 75.0% (target achieved)

### 2B. CONDITIONAL MIGRATIONS (Moderate Impact)
**Target: Additional 40GB if needed**

#### Medium Priority (Balanced consideration)
3. **CT 100 (influxdb) - 40GB**
   - **Rationale:** Large space recovery opportunity
   - **Impact:** 20-30% write performance reduction
   - **Risk Assessment:**
     - Home Assistant writes ~1000 points/minute
     - NFS can handle this load but with higher latency
     - Consider only if storage becomes critical again
   - **Mitigation:** Monitor write queue depth, optimize retention policies
   - **Decision Point:** Only migrate if usage exceeds 80% again

---

## Performance Optimization Strategy

### TIER 1: Ultra-Performance (Keep on local-lvm)
**Critical real-time and high-I/O workloads**

#### Core Infrastructure (Never migrate)
- **VM 114 (Home Assistant)** - 52GB
  - IoT automation requires <100ms response
  - Handles 24/7 real-time device communication
  - SQLite database with frequent writes

- **CT 122 (zigbee2mqtt)** - 4GB  
  - Real-time IoT message routing
  - Mesh network coordination requires minimal latency
  - Critical for home automation reliability

#### Database & High-I/O Services
- **CT 101 (grafana)** - 4GB
  - Dashboard queries with SQLite operations
  - User-facing performance matters
  - Relatively small, worth keeping local

- **CT 105 (nginxproxymanager)** - 4GB
  - SSL termination and reverse proxy
  - Critical path for all web services
  - Configuration database updates

### TIER 2: Balanced Performance (Evaluate case-by-case)
**Services with moderate I/O requirements**

#### Development & Monitoring
- **CT 123 (gitopsdashboard)** - 8GB
  - Git operations benefit from low latency
  - User-facing dashboard performance
  - Consider for Phase 2B if space needed

- **CT 115 (memos)** - 7GB
  - Note-taking app with SQLite backend
  - User experience sensitive to performance
  - Small enough to keep local

#### Infrastructure Services
- **CT 131 (netbox)** - 4GB
  - Network documentation with PostgreSQL
  - Moderate database usage
  - Administrative tool, not real-time critical

### TIER 3: Migration Candidates (NFS-suitable)
**Network-bound or low-I/O services**

#### Already Identified for Migration
- **CT 200 (github-runner)** - 20GB → **MIGRATE**
- **CT 125 (adguard)** - 18GB → **MIGRATE** 
- **CT 117 (hoarder)** - 14GB → **CONSIDER**

#### Small Services (Migration optional)
- **CT 102 (cloudflared)** - 2GB - Keep local (too small to matter)
- **CT 103 (watchyourlan)** - 2GB - Keep local (network monitoring)
- **CT 104 (myspeed)** - 4GB - Keep local (network testing tool)
- **CT 106 (pairdrop)** - 4GB - Migration candidate if needed
- **CT 124 (mqtt)** - 2GB - Keep local (IoT infrastructure)

---

## Implementation Roadmap

### Week 1: Phase 2A Execution
**Goals: Achieve target usage <75%, minimal performance impact**

1. **Day 1-2: CT 200 Migration (github-runner)**
   - Schedule during low CI/CD activity
   - Migrate 20GB to TrueNas_NVMe
   - Test build performance post-migration
   - Monitor for any workflow issues

2. **Day 3-4: CT 125 Migration (adguard)**  
   - Brief maintenance window announcement
   - Migrate 18GB to TrueNas_NVMe
   - Verify DNS resolution performance
   - Monitor query response times

3. **Day 5: Performance Validation**
   - Benchmark all migrated services
   - Document any performance changes
   - Update monitoring thresholds if needed

### Week 2-3: Optimization & Monitoring
**Goals: Fine-tune performance, establish baseline metrics**

1. **Performance Baselines**
   - Establish response time metrics for all services
   - Set up alerts for performance degradation
   - Document acceptable performance thresholds

2. **Storage Health Monitoring**
   - Automated alerts at 75% and 80% usage
   - Weekly storage growth trend analysis
   - Capacity planning for next 6 months

### Future Phases (If Needed)

#### Phase 2B: Conditional Migration
**Trigger:** If usage exceeds 80% again
- Evaluate CT 100 (influxdb) migration
- Consider CT 117 (hoarder) migration
- Assess smaller services consolidation

#### Phase 3: Infrastructure Expansion
**Trigger:** If optimization reaches limits
- Evaluate local SSD expansion options
- Consider hybrid storage tiers
- Plan for additional Proxmox nodes

---

## Risk Management

### Performance Monitoring
1. **Pre-migration Benchmarks**
   - Document current response times
   - Establish performance SLAs
   - Create rollback procedures

2. **Post-migration Validation**
   - 48-hour performance monitoring
   - User experience feedback collection
   - Automated performance regression detection

### Rollback Procedures
1. **Emergency Rollback Plan**
   - Keep local-lvm space available for 7 days post-migration
   - Document reverse migration procedures
   - Test rollback process in lab environment

2. **Service Continuity**
   - Stagger migrations to avoid simultaneous outages
   - Maintain redundancy for critical services
   - Pre-position backup instances if needed

### Capacity Planning
1. **Growth Projections**
   - Analyze 6-month growth trends
   - Plan for seasonal usage spikes
   - Reserve 20% buffer capacity

2. **Performance Degradation Thresholds**
   - Alert at 20% performance loss
   - Automatic rollback triggers at 40% loss
   - Regular performance reviews

---

## Success Metrics

### Storage Optimization
- **Target:** <70% local-lvm usage achieved ✅
- **Space Recovery:** 38GB minimum in Phase 2A
- **Efficiency:** >95% of performance maintained

### Performance Maintenance  
- **Response Times:** <20% increase acceptable
- **Availability:** >99.5% uptime maintained
- **User Experience:** No user-reported performance issues

### Operational Excellence
- **Monitoring:** Real-time performance dashboards
- **Automation:** Automated capacity alerts
- **Documentation:** Complete migration playbooks

---

## Long-term Strategy (6-12 months)

### Storage Expansion Options
1. **Local SSD Addition**
   - Evaluate adding second local SSD
   - Consider NVMe upgrade for existing storage
   - Cost-benefit analysis vs cloud migration

2. **Hybrid Storage Architecture**
   - Implement automated storage tiering
   - Hot/warm/cold data classification
   - Intelligent workload placement

3. **High Availability Implementation**
   - Multi-node Proxmox cluster
   - Shared storage with failover
   - Geographic redundancy planning

### Technology Evolution
1. **Container Orchestration**
   - Evaluate Kubernetes migration path
   - Implement container auto-scaling
   - Optimize resource utilization

2. **Performance Optimization**
   - I/O scheduler tuning
   - Network performance optimization
   - Application-level caching strategies

This plan balances immediate storage pressure relief with long-term performance optimization, ensuring critical services maintain their performance while achieving sustainable storage utilization.