# ============================================
# Argo CD MTTD / MTTR Messung mit Git Push
# ============================================

Write-Host "Starte Messung..."

# 1. Aktuelle Deployment-Generation vor dem Push speichern
$old_gen = kubectl get deployment meine-test-app -n default -o jsonpath='{.metadata.generation}'

Write-Host "Alte Deployment Generation: $old_gen"

# 2. Git Änderungen vorbereiten
Write-Host "Führe Git Commit aus..."

git add .

git commit -m "Messung: $(Get-Date)"

# 3. Startzeit direkt vor Git Push setzen
$start_push = Get-Date

Write-Host "Push gestartet um: $start_push"

# 4. Git Push ausführen
git push origin main

Write-Host "Git Push abgeschlossen."

# 5. Warten auf MTTD: Argo CD erkennt Änderung
Write-Host "Warte auf Detektion durch ArgoCD..."

while ($true) {

    $new_gen = kubectl get deployment meine-test-app -n default -o jsonpath='{.metadata.generation}'

    if ($new_gen -ne $old_gen) {

        $mttd_end = Get-Date

        Write-Host "Änderung erkannt!"
        Write-Host "Neue Deployment Generation: $new_gen"

        break
    }

    Start-Sleep -Seconds 0.5
}


# 6. Warten auf fertiges Deployment
Write-Host "Warte auf Ready-Status (MTTR)..."

kubectl rollout status deployment meine-test-app -n default --timeout=300s | Out-Null

$mttr_end = Get-Date


# 7. Zeiten berechnen

$mttd = $mttd_end - $start_push
$mttr = $mttr_end - $start_push


# 8. Ausgabe

Write-Host ""
Write-Host "============================"
Write-Host "Messung abgeschlossen"
Write-Host "============================"
Write-Host "MTTD (Detektion): $($mttd.TotalSeconds) Sekunden"
Write-Host "MTTR (Gesamtdauer): $($mttr.TotalSeconds) Sekunden"
Write-Host "============================"