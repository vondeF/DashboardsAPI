using System.Text.Json.Serialization;
using DashboardsAPI;
using DashboardsAPI.Helpers;

var builder = WebApplication.CreateBuilder(args);

var services = builder.Services;

services.AddCors();
services.AddControllers();
services.AddAutoMapper(AppDomain.CurrentDomain.GetAssemblies());

var app = builder.Build();

app.UseCors(x => x
        .AllowAnyOrigin()
        .AllowAnyMethod()
        .AllowAnyHeader());
app.UseMiddleware<ErrorHandlerMiddleware>();
app.MapControllers();

app.Run("http://0.0.0.0:5000");
