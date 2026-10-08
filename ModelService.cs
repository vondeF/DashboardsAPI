using System.Collections.Specialized;
using System.Net;
using System.Security.Authentication;
using System.Text;
using DashboardsAPI.Helpers;
using Newtonsoft.Json.Linq;
using System.Text.Json;
using System.Net.Http.Headers;

namespace DashboardsAPI
{
    public class ModelService
    {
        Uri _modelUri;
        Uri _authUri;
        string _token;
        HttpClient _httpClient;

        public ModelService(string authUriString, string modelUriString)
        {
            this._authUri = new Uri(authUriString);
            this._modelUri = new Uri(modelUriString);

            this._httpClient = new HttpClient(new HttpClientHandler { 
                Credentials = CredentialCache.DefaultCredentials, 
                AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate | DecompressionMethods.Brotli,
                UseCookies = true,
                CookieContainer = new CookieContainer()
            });
            this._httpClient.Timeout = TimeSpan.FromSeconds(300);
            this._httpClient.DefaultRequestHeaders.Add("Accept", "application/json");
            this._httpClient.DefaultRequestHeaders.Add("Accept-Encoding", "gzip, deflate, br, zstd");
            this._httpClient.DefaultRequestHeaders.Add("Accept-Language", "ru,en;q=0.9");
        }
        
        public async Task<JsonElement> RunScriptAsync(string script, string scriptName)
        {
            try
            {
                _token = await GetAuthTokenAsync();

                this._httpClient.DefaultRequestHeaders.Authorization = null;
                this._httpClient.DefaultRequestHeaders.Remove("Authorization");
                this._httpClient.DefaultRequestHeaders.Add("Authorization", "Bearer " + this._token);

                var mainUri = new Uri($"{this._modelUri}/execute-script");
                var content = new StringContent(script, Encoding.UTF8, "application/json");

                var response = await this._httpClient.PostAsync(mainUri, content);
                var responseBytes = await response.Content.ReadAsByteArrayAsync();
                var responseContent = Encoding.UTF8.GetString(responseBytes);

                if (response.IsSuccessStatusCode)
                {
                    try
                    {
                        return JsonSerializer.Deserialize<dynamic>(responseContent);
                    }
                    catch (JsonException ex)
                    {
                        throw new LuaScriptException($"Invalid JSON response: {ex.Message}", scriptName);
                    }
                }
                throw response.StatusCode switch
                {
                    HttpStatusCode.BadRequest => new LuaScriptException(responseContent, scriptName),
                    HttpStatusCode.Unauthorized => new UnauthorizedAccessException("Invalid or expired token"),
                    HttpStatusCode.Forbidden => new UnauthorizedAccessException("Access forbidden"),
                    HttpStatusCode.NotFound => new HttpRequestException($"Script endpoint not found: {responseContent}"),
                    HttpStatusCode.InternalServerError => new HttpRequestException($"Server error: {responseContent}"),
                    _ => new HttpRequestException($"Unexpected error {response.StatusCode}: {responseContent}")
                };
            }
            catch (HttpRequestException ex) when (ex.InnerException is TaskCanceledException)
            {
                throw new TimeoutException($"Request timed out after {_httpClient.Timeout.TotalSeconds} seconds", ex);
            }
            catch (TaskCanceledException ex)
            {
                throw new TimeoutException("Request was cancelled", ex);
            }
        }

        private async Task<string> GetAuthTokenAsync()
        {
            try
            {
                var response = await this._httpClient.PostAsync(_authUri, null);
                var content = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                    throw new UnauthorizedAccessException($"Authentication failed with status {response.StatusCode}: {content}");

                var json = JObject.Parse(content);
                var token = json.Value<string>("access_token");

                if (string.IsNullOrEmpty(token))
                    throw new UnauthorizedAccessException("Token is null or empty");

                return token;
            }
            catch (HttpRequestException ex) when (ex.InnerException is TaskCanceledException)
            {
                throw new TimeoutException("Authentication request timed out", ex);
            }
        }
    }
}
