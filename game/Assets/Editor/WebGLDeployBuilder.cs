using System;
using System.IO;
using System.IO.Compression;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class WebGLDeployBuilder
{
    private const string ScenePath = "Assets/Scenes/VendingScene.unity";
    private const string WebGlBuildPath = "Builds/WebGL";
    private const string LinuxBuildPath = "Builds/Linux/GemeloVending.x86_64";
    private const string ZipOutputPath = "Builds/GemeloVending_WebGL.zip";

    [MenuItem("GROG/Compilar WebGL para Despliegue Web (Navegador/itch.io)")]
    public static void BuildWebGL()
    {
        Debug.Log("[GROG WebGL] Iniciando compilación de Gemelo Digital para la Web (WebGL)...");

        // 1. Asegurar configuración de Player para WebGL
        PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Gzip;
        PlayerSettings.WebGL.decompressionFallback = true;
        PlayerSettings.WebGL.memorySize = 256;
        PlayerSettings.runInBackground = true;

        if (Directory.Exists(WebGlBuildPath))
        {
            try { Directory.Delete(WebGlBuildPath, true); } catch { }
        }
        Directory.CreateDirectory(WebGlBuildPath);

        string[] scenes = new string[] { ScenePath };

        BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = WebGlBuildPath,
            target = BuildTarget.WebGL,
            options = BuildOptions.None
        };

        BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
        BuildSummary summary = report.summary;

        if (summary.result == BuildResult.Succeeded)
        {
            Debug.Log($"[GROG WebGL] ¡Compilación WebGL exitosa! ({summary.totalSize / (1024 * 1024)} MB en {summary.totalTime.TotalSeconds:F1}s)");

            // 2. Crear paquete ZIP listo para itch.io / Hosting Web
            try
            {
                if (File.Exists(ZipOutputPath)) File.Delete(ZipOutputPath);
                ZipFile.CreateFromDirectory(WebGlBuildPath, ZipOutputPath);
                Debug.Log($"[GROG WebGL] ¡Archivo ZIP listo para subir a itch.io generado en: {ZipOutputPath}!");
            }
            catch (Exception ex)
            {
                Debug.LogWarning($"[GROG WebGL] No se pudo crear el ZIP automático: {ex.Message}");
            }

            // 3. Copiar a la carpeta backend para servicio Docker/Nginx
            try
            {
                string dockerDistDir = Path.GetFullPath("../Maquina-expendedora/backend/unity-webgl/dist");
                if (!Directory.Exists(dockerDistDir)) Directory.CreateDirectory(dockerDistDir);
                CopyDirectory(WebGlBuildPath, dockerDistDir);
                Debug.Log($"[GROG WebGL] Archivos copiados para Docker Nginx en: {dockerDistDir}");
            }
            catch (Exception ex)
            {
                Debug.LogWarning($"[GROG WebGL] Nota sobre copia a Docker: {ex.Message}");
            }
        }
        else if (summary.result == BuildResult.Failed)
        {
            Debug.LogError($"[GROG WebGL] Falló la compilación WebGL ({summary.totalErrors} errores).");
        }
    }

    [MenuItem("GROG/Compilar Ejecutable Linux Standalone (.x86_64)")]
    public static void BuildLinux()
    {
        Debug.Log("[GROG Standalone] Compilando ejecutable nativo Linux...");

        string dir = Path.GetDirectoryName(LinuxBuildPath);
        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

        BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
        {
            scenes = new string[] { ScenePath },
            locationPathName = LinuxBuildPath,
            target = BuildTarget.StandaloneLinux64,
            options = BuildOptions.None
        };

        BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
        if (report.summary.result == BuildResult.Succeeded)
        {
            Debug.Log($"[GROG Standalone] ¡Ejecutable Linux generado exitosamente en: {LinuxBuildPath}!");
        }
        else
        {
            Debug.LogError("[GROG Standalone] Falló la compilación Linux Standalone.");
        }
    }

    private static void CopyDirectory(string sourceDir, string destinationDir)
    {
        DirectoryInfo dir = new DirectoryInfo(sourceDir);
        if (!dir.Exists) return;

        Directory.CreateDirectory(destinationDir);

        foreach (FileInfo file in dir.GetFiles())
        {
            string targetFilePath = Path.Combine(destinationDir, file.Name);
            file.CopyTo(targetFilePath, true);
        }

        foreach (DirectoryInfo subDir in dir.GetDirectories())
        {
            string nextTargetSubDir = Path.Combine(destinationDir, subDir.Name);
            CopyDirectory(subDir.FullName, nextTargetSubDir);
        }
    }
}
