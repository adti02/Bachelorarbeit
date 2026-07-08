# ============================================
# Argo CD GitOps MTTD / MTTR Messung
# ============================================

$app = "test1"
$namespace = "argocd"


Write-Host "Starte Messung..."


# Git vorbereiten

git add .

git commit -m "Messung: $(Get-Date)"


$start_push = Get-Date


Write-Host "Push gestartet: $start_push"


git push origin main


if ($LASTEXITCODE -ne 0) {
    Write-Host "Push fehlgeschlagen!" -ForegroundColor Red
    exit
}


$push_finished = Get-Date


Write-Host "Push abgeschlossen."



# ============================================
# MTTD
# ============================================

Write-Host "Warte auf Argo Erkennung..."


while ($true) {


    $sync = kubectl get application $app `
        -n $namespace `
        -o jsonpath='{.status.sync.status}'


    if ($sync -eq "OutOfSync") {


        $mttd_end = Get-Date

        Write-Host "Argo hat Änderung erkannt!"

        break
    }


    Start-Sleep -Milliseconds 500

}




# ============================================
# MTTR
# ============================================


Write-Host "Warte auf Synchronisierung..."


while ($true) {


    $sync = kubectl get application $app `
        -n $namespace `
        -o jsonpath='{.status.sync.status}'


    $health = kubectl get application $app `
        -n $namespace `
        -o jsonpath='{.status.health.status}'



    if (($sync -eq "Synced") -and ($health -eq "Healthy")) {


        $mttr_end = Get-Date

        break
    }


    Start-Sleep -Milliseconds 500
}




$mttd = $mttd_end - $push_finished

$mttr = $mttr_end - $push_finished



Write-Host ""
Write-Host "============================"
Write-Host "Messung abgeschlossen"
Write-Host "============================"

Write-Host "MTTD: $($mttd.TotalSeconds) Sekunden"
Write-Host "MTTR: $($mttr.TotalSeconds) Sekunden"

Write-Host "============================"