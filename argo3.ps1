# ==============================================================================
# GITOPS MESS-SKRIPT FÜR ARGO CD
# Automatischer Drift-Test mit MTTD und MTTR
# ==============================================================================


# --- KONFIGURATION ---

$deployment = "meine-test-app"
$appName = "test1"
$argoNamespace = "argocd"
$runs = 5


# Git Soll-Zustand
$desiredReplicas = 3


# --- SPEICHER ---

$mttdList = @()
$mttrList = @()



# Namespace automatisch finden

$namespace = kubectl get deployment $deployment `
    --all-namespaces `
    -o jsonpath='{.items[0].metadata.namespace}' 2>$null


if (-not $namespace) {
    $namespace = "default"
}



Clear-Host

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " ARGO CD DRIFT MESSUNG" -ForegroundColor Yellow
Write-Host " Deployment: $deployment" -ForegroundColor Yellow
Write-Host " Application: $appName" -ForegroundColor Yellow
Write-Host " Namespace: $namespace" -ForegroundColor Yellow
Write-Host " Durchläufe: $runs" -ForegroundColor Yellow
Write-Host "============================================================"



for ($i = 1; $i -le $runs; $i++) {


    Write-Host ""
    Write-Host "--- Durchgang $i von $runs ---" -ForegroundColor Cyan



    # --------------------------------------------------------------------------
    # T0: Drift erzeugen
    # --------------------------------------------------------------------------

    $T0 = [DateTimeOffset]::UtcNow


    kubectl scale deployment/$deployment `
        --replicas=5 `
        -n $namespace | Out-Null


    Write-Host "Drift erzeugt: replicas=5"



    # --------------------------------------------------------------------------
    # MTTD:
    # Warten bis Argo OutOfSync erkennt
    # --------------------------------------------------------------------------


    Write-Host "Warte auf Argo Drift-Erkennung..."


    $detected = $false


    while (-not $detected) {


        Start-Sleep -Milliseconds 300


        $syncStatus = kubectl get application $appName `
            -n $argoNamespace `
            -o jsonpath='{.status.sync.status}' 2>$null



        if ($syncStatus -eq "OutOfSync") {


            $T_detect = [DateTimeOffset]::UtcNow


            $detected = $true


            Write-Host "Argo hat Drift erkannt" -ForegroundColor Green

        }

    }



    # --------------------------------------------------------------------------
    # MTTR:
    # Warten bis Argo repariert hat
    # --------------------------------------------------------------------------


    Write-Host "Warte auf Wiederherstellung..."


    $recovered = $false


    while (-not $recovered) {


        Start-Sleep -Milliseconds 500



        $syncStatus = kubectl get application $appName `
            -n $argoNamespace `
            -o jsonpath='{.status.sync.status}' 2>$null



        $healthStatus = kubectl get application $appName `
            -n $argoNamespace `
            -o jsonpath='{.status.health.status}' 2>$null



        $replicas = kubectl get deployment/$deployment `
            -n $namespace `
            -o jsonpath='{.spec.replicas}' 2>$null



        if (
            ($syncStatus -eq "Synced") -and
            ($healthStatus -eq "Healthy") -and
            ($replicas -eq "$desiredReplicas")
        ) {


            $T_finish = [DateTimeOffset]::UtcNow


            $recovered = $true


            Write-Host "Argo Wiederherstellung abgeschlossen" -ForegroundColor Green

        }

    }




    # --------------------------------------------------------------------------
    # Berechnung
    # --------------------------------------------------------------------------


    $mttd = ($T_detect - $T0).TotalMilliseconds

    $mttr = ($T_finish - $T0).TotalMilliseconds



    $mttdList += $mttd
    $mttrList += $mttr



    Write-Host ""
    Write-Host "MTTD: $([math]::Round($mttd/1000,2)) Sekunden"
    Write-Host "MTTR: $([math]::Round($mttr/1000,2)) Sekunden"



    if ($i -lt $runs) {

        Write-Host "Abkühlphase 30 Sekunden..."
        Start-Sleep -Seconds 30

    }

}



# ==============================================================================
# AUSWERTUNG
# ==============================================================================


$avgMttd = (($mttdList | Measure-Object -Average).Average) / 1000

$avgMttr = (($mttrList | Measure-Object -Average).Average) / 1000



Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " ARGO CD MESSERGEBNIS" -ForegroundColor Yellow
Write-Host "============================================================"

Write-Host "Durchläufe: $runs"
Write-Host "Durchschnittliche MTTD: $([math]::Round($avgMttd,2)) Sekunden"
Write-Host "Durchschnittliche MTTR: $([math]::Round($avgMttr,2)) Sekunden"

Write-Host "============================================================"