const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000/api/v1";

function authHeaders() {
  if (typeof window === "undefined") {
    return {};
  }
  const token = localStorage.getItem("zests_admin_token");
  if (!token) {
    return {};
  }
  return { Authorization: `Bearer ${token}` };
}

async function apiRequest<T>(method: string, path: string, body?: unknown): Promise<T> {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    cache: "no-store",
    headers: {
      "Content-Type": "application/json",
      ...authHeaders(),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed: ${response.status}`);
  }
  if (response.status === 204) {
    return {} as T;
  }
  return (await response.json()) as T;
}

export async function apiGet<T>(path: string): Promise<T> {
  return apiRequest<T>("GET", path);
}

export async function apiPost<T>(path: string, body: unknown): Promise<T> {
  return apiRequest<T>("POST", path, body);
}

export async function apiPut<T>(path: string, body: unknown): Promise<T> {
  return apiRequest<T>("PUT", path, body);
}

export async function apiDelete<T>(path: string): Promise<T> {
  return apiRequest<T>("DELETE", path);
}
