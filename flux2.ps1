# ============================================
# Flux CD GitOps MTTD / MTTR Messung
# ============================================

$deployment = "meine-test-app"
$namespace = "default"

$gitRepository = "flux-system"
$fluxNamespace = "flux-system"


Write-Host "Starte Flux Messung..."


# ============================================
# Alten Git Stand von Flux speichern
# ============================================

$old_revision = kubectl get gitrepository $gitRepository `
    -n $fluxNamespace `
    -o jsonpath='{.status.artifact.revision}'


Write-Host "Alte Flux Revision:"
Write-Host $old_revision



# ============================================
# Git Änderung vorbereiten
# ============================================

Write-Host "Führe Git Commit aus..."

git add .

git commit -m "Messung: $(Get-Date)"



# ============================================
# Push Zeit starten
# ============================================

$start_push = Get-Date


Write-Host "Push gestartet: $start_push"



git push origin main



if ($LASTEXITCODE -ne 0) {

    Write-Host "Git Push fehlgeschlagen!" -ForegroundColor Red
    exit

}



$push_finished = Get-Date


Write-Host "Git Push abgeschlossen."



# ============================================
# MTTD:
# Flux erkennt neue Revision
# ============================================


Write-Host "Warte auf Flux Erkennung..."



while ($true) {


    $new_revision = kubectl get gitrepository $gitRepository `
        -n $fluxNamespace `
        -o jsonpath='{.status.artifact.revision}'


    if (($new_revision) -and ($new_revision -ne $old_revision)) {


        $mttd_end = Get-Date


        Write-Host "Flux hat neue Revision erkannt!"
        Write-Host "Neue Revision:"
        Write-Host $new_revision


        break
    }


    Start-Sleep -Milliseconds 500

}




# ============================================
# MTTR:
# Deployment wieder bereit
# ============================================


Write-Host "Warte auf fertiges Deployment..."



kubectl rollout status deployment/$deployment `
    -n $namespace `
    --timeout=300s | Out-Null



$mttr_end = Get-Date



# ============================================
# Berechnung
# ============================================


$mttd = $mttd_end - $push_finished

$mttr = $mttr_end - $push_finished



Write-Host ""
Write-Host "============================"
Write-Host "Flux Messung abgeschlossen"
Write-Host "============================"

Write-Host "MTTD (Git -> Flux erkannt): $($mttd.TotalSeconds) Sekunden"

Write-Host "MTTR (Git -> Deployment fertig): $($mttr.TotalSeconds) Sekunden"

Write-Host "============================"