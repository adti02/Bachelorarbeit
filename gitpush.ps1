
cat argo2.ps1 | powershell
# 1. Zeitstempel VOR dem Push nehmen
$start_push = Get-Date

# 2. Git Befehle
git add .
git commit -m "Messung: $(Get-Date)"
git push origin main

cat argo2.ps1 | powershell