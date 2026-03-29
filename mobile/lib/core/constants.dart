const kApiBaseUrl = String.fromEnvironment(
  "API_BASE_URL",
  defaultValue: "https://zestsmvp-backend.onrender.com/api/v1",
);

const kTermsPageUrl = String.fromEnvironment(
  "TERMS_PAGE_URL",
  defaultValue: "https://zestsmvp-backend.onrender.com/api/v1/pages/terms-and-conditions",
);

const kProfileCacheKey = "cached_profile";
const kFirstOpenKey = "is_first_open";

String imageUrl(String? path) {
  if (path == null || path.isEmpty) return "";
  if (path.startsWith("http")) return path;
  final base = kApiBaseUrl.replaceAll("/api/v1", "");
  return "$base$path";
}
