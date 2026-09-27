Option Explicit

Dim sh, root, py, sitepkgs, oldPath, newPath, cmd
Set sh = CreateObject("WScript.Shell")

root = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\WhisperSeamless"
py = root & "\runtime\Python312\pythonw.exe"
sitepkgs = root & "\runtime\Python312\Lib\site-packages"

oldPath = sh.Environment("PROCESS")("PATH")
newPath = sitepkgs & "\nvidia\cuda_runtime\bin;" & _
          sitepkgs & "\nvidia\cublas\bin;" & _
          sitepkgs & "\nvidia\cudnn\bin;" & oldPath

sh.Environment("PROCESS")("PATH") = newPath

cmd = """" & py & """ """ & root & "\\scripts\\launch_with_binding.py" & """"
sh.Run cmd, 0, False
