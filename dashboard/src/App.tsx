// src/App.tsx
// (No changes to this file)

import { useEffect, useState } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  Legend
} from "recharts";

// Repo type definition (for TypeScript)
type Repo = {
  name: string;
  path: string;
  remote?: string;
  branch?: string;
  lastCommit?: string;
  lastCommitAgeDays?: number;
  uncommittedChanges: boolean;
  missingFiles: string[];
  isStale: boolean;
};

export default function App() {
  const [data, setData] = useState<Repo[]>([]);
  const [query, setQuery] = useState("");
  const [source, setSource] = useState<"local" | "github">("local");
  const [refreshInterval, setRefreshInterval] = useState<number>(10000);

  const sourceUrl =
    source === "local"
      ? "/GitRepoReport.json"
      : "https://raw.githubusercontent.com/festion/homelab-gitops-auditor/main/output/GitRepoReport.json";

  useEffect(() => {
    const fetchData = () => {
      fetch(sourceUrl)
        .then((res) => res.json())
        .then((json) => setData(json))
        .catch((err) => console.error("Failed to load report:", err));
    };

    fetchData();
    const interval = setInterval(fetchData, refreshInterval);
    return () => clearInterval(interval);
  }, [sourceUrl, refreshInterval]);

  const filtered = data.filter((repo) =>
    repo.name.toLowerCase().includes(query.toLowerCase())
  );

  const badge = (label: string, condition: boolean) => (
    <span
      className={`text-xs px-2 py-1 rounded-full font-semibold border ${
        condition
          ? "bg-red-100 text-red-800 border-red-300"
          : "bg-green-100 text-green-800 border-green-300"
      }`}
    >
      {label}: {condition ? "Yes" : "No"}
    </span>
  );

  const dirty = data.filter((r) => r.uncommittedChanges).length;
  const stale = data.filter((r) => r.isStale).length;
  const missing = data.filter((r) => r.missingFiles.length > 0).length;

  const summaryData = [
    { name: "Uncommitted", value: dirty },
    { name: "Stale", value: stale },
    { name: "Missing Files", value: missing },
  ];

  const colors = ["#ef4444", "#f59e0b", "#6366f1"];

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-3xl font-bold mb-4">🧭 GitOps Audit Dashboard</h1>

        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6 gap-4">
          <input
            type="text"
            placeholder="Search repositories..."
            className="w-full sm:w-1/2 border border-gray-300 rounded-md px-4 py-2 shadow-sm"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />

          <div className="flex items-center gap-2">
            <label className="text-sm font-medium">📁 Data Source:</label>
            <select
              value={source}
              onChange={(e) => setSource(e.target.value as "local" | "github")}
              className="border border-gray-300 rounded px-3 py-1 text-sm shadow-sm"
            >
              <option value="local">Local</option>
              <option value="github">GitHub</option>
            </select>

            <label className="text-sm font-medium ml-4">⏱ Refresh:</label>
            <select
              value={refreshInterval}
              onChange={(e) => setRefreshInterval(Number(e.target.value))}
              className="border border-gray-300 rounded px-3 py-1 text-sm shadow-sm"
            >
              <option value={5000}>5s</option>
              <option value={10000}>10s</option>
              <option value={30000}>30s</option>
              <option value={60000}>60s</option>
            </select>
          </div>
        </div>

        <div className="mb-10 grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="h-64 bg-white shadow rounded-xl p-4">
            <h2 className="text-lg font-semibold mb-2">📊 Repo Health (Bar)</h2>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={summaryData}>
                <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                <YAxis allowDecimals={false} />
                <Tooltip />
                <Bar dataKey="value">
                  {summaryData.map((_, index) => (
                    <Cell key={`bar-${index}`} fill={colors[index % colors.length]} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className="h-64 bg-white shadow rounded-xl p-4">
            <h2 className="text-lg font-semibold mb-2">📈 Repo Breakdown (Pie)</h2>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={summaryData}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="45%"
                  outerRadius={70}
                  labelLine={false}
                  label={({ name, percent }) => `${name} (${(percent * 100).toFixed(0)}%)`}
                >
                  {summaryData.map((_, index) => (
                    <Cell key={`cell-${index}`} fill={colors[index % colors.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend verticalAlign="bottom" iconType="circle" iconSize={10} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {filtered.map((repo) => (
            <div
              key={repo.name}
              className="bg-white shadow-md rounded-xl p-4 border border-gray-200"
            >
              <h2 className="text-xl font-semibold mb-2">{repo.name}</h2>
              <p className="text-sm text-gray-600 mb-1">
                Branch: <span className="font-mono">{repo.branch}</span>
              </p>
              <p className="text-sm text-gray-600 mb-1">
                Last Commit: <span className="font-mono">{repo.lastCommit}</span>
              </p>
              <p className="text-sm text-gray-600 mb-2">
                Remote: {repo.remote || <span className="italic text-gray-400">None</span>}
              </p>

              <div className="flex flex-wrap gap-2">
                {badge("Uncommitted", repo.uncommittedChanges)}
                {badge("Stale", repo.isStale)}
                {badge("Missing Files", repo.missingFiles?.length > 0)}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
