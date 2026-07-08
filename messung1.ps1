# ==============================================================================
# GITOPS DRIFT MESSUNG - FLUX / ARGO VERGLEICH
# MTTD + MTTR
#
# MTTD:
# Zeitpunkt Drift erzeugt bis Controller beginnt zu reparieren
#
# MTTR:
# Zeitpunkt Drift erzeugt bis Soll-Zustand wiederhergestellt ist
# ==============================================================================


# ================= KONFIGURATION ==============================================

$deployment = "meine-test-app"
$namespace = "default"

$runs = 5

$desiredReplicas = 3
$driftReplicas = 5

$checkIntervalMs = 500
$cooldownSeconds = 90



# ================= SPEICHER ===================================================

$mttdList = @()
$mttrList = @()



Clear-Host

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " GITOPS DRIFT MESSUNG - MTTD / MTTR" -ForegroundColor Yellow
Write-Host " Deployment: $deployment" -ForegroundColor Yellow
Write-Host " Namespace: $namespace" -ForegroundColor Yellow
Write-Host " Durchläufe: $runs" -ForegroundColor Yellow
Write-Host "============================================================"



for ($i = 1; $i -le $runs; $i++) {


    Write-Host ""
    Write-Host "--- Durchgang $i von $runs ---" -ForegroundColor Cyan



    # --------------------------------------------------------------------------
    # Sicherstellen: Ausgangszustand
    # --------------------------------------------------------------------------

    $replicas = kubectl get deployment/$deployment `
        -n $namespace `
        -o jsonpath='{.spec.replicas}' 2>$null


    while ($replicas -ne "$desiredReplicas") {

        Start-Sleep -Milliseconds $checkIntervalMs

        $replicas = kubectl get deployment/$deployment `
            -n $namespace `
            -o jsonpath='{.spec.replicas}' 2>$null
    }



    # --------------------------------------------------------------------------
    # Drift erzeugen
    # --------------------------------------------------------------------------

    $T0 = [DateTimeOffset]::UtcNow


    kubectl scale deployment/$deployment `
        --replicas=$driftReplicas `
        -n $namespace | Out-Null


    Write-Host "Drift erzeugt: replicas=$driftReplicas"



    # --------------------------------------------------------------------------
    # MTTD:
    # Warten bis Reparatur beginnt
    # --------------------------------------------------------------------------

    $detected = $false


    while (-not $detected) {


        Start-Sleep -Milliseconds $checkIntervalMs


        $replicas = kubectl get deployment/$deployment `
            -n $namespace `
            -o jsonpath='{.spec.replicas}' 2>$null



        if ($replicas -ne "$driftReplicas") {


            $T_detect = [DateTimeOffset]::UtcNow

            $detected = $true

        }

    }



    # --------------------------------------------------------------------------
    # MTTR:
    # Warten bis Soll-Zustand erreicht
    # --------------------------------------------------------------------------

    $recovered = $false


    while (-not $recovered) {


        Start-Sleep -Milliseconds $checkIntervalMs


        $replicas = kubectl get deployment/$deployment `
            -n $namespace `
            -o jsonpath='{.spec.replicas}' 2>$null



        if ($replicas -eq "$desiredReplicas") {


            $T_finish = [DateTimeOffset]::UtcNow

            $recovered = $true

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
    Write-Host "MTTD: $([math]::Round($mttd / 1000,2)) Sekunden"
    Write-Host "MTTR: $([math]::Round($mttr / 1000,2)) Sekunden"



    if ($i -lt $runs) {

        Write-Host "Abkühlphase $cooldownSeconds Sekunden..."

        Start-Sleep -Seconds $cooldownSeconds

    }

}



# ================= AUSWERTUNG =================================================


$avgMttd = (($mttdList | Measure-Object -Average).Average) / 1000
$avgMttr = (($mttrList | Measure-Object -Average).Average) / 1000



Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " ERGEBNIS" -ForegroundColor Yellow
Write-Host "============================================================"

Write-Host "Durchläufe: $runs"
Write-Host "Durchschnittliche MTTD: $([math]::Round($avgMttd,2)) Sekunden"
Write-Host "Durchschnittliche MTTR: $([math]::Round($avgMttr,2)) Sekunden"

Write-Host ""
Write-Host "Einzelwerte:"
Write-Host ""

for ($i = 0; $i -lt $runs; $i++) {

    Write-Host "Run $($i+1): MTTD=$([math]::Round($mttdList[$i]/1000,2))s | MTTR=$([math]::Round($mttrList[$i]/1000,2))s"

}

Write-Host "============================================================"