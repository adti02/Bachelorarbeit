# ==============================================================================
# GITOPS DRIFT MESSUNG - ARGO / FLUX VERGLEICH
# MTTD + MTTR
#
# MTTD:
# Drift erzeugt bis Controller beginnt zu reparieren
#
# MTTR:
# Drift erzeugt bis Sollzustand wiederhergestellt ist
#
# Messung über Kubernetes Zustand (controller-unabhängig)
# ==============================================================================


# ================= KONFIGURATION ==============================================

$controller = "argo"   # nur zur Dokumentation: "argo" oder "flux"

$deployment = "meine-test-app"
$namespace = "default"

$runs = 5

$desiredReplicas = 3
$driftReplicas = 5

$checkIntervalMs = 100
$cooldownSeconds = 120



# ================= SPEICHER ===================================================

$mttdList = @()
$mttrList = @()



Clear-Host

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " GITOPS DRIFT MESSUNG" -ForegroundColor Yellow
Write-Host " Controller: $controller" -ForegroundColor Yellow
Write-Host " Deployment: $deployment" -ForegroundColor Yellow
Write-Host " Namespace: $namespace" -ForegroundColor Yellow
Write-Host " Durchläufe: $runs" -ForegroundColor Yellow
Write-Host "============================================================"



# ================= FUNKTIONEN =================================================


function Get-Replicas {

    return kubectl get deployment/$deployment `
        -n $namespace `
        -o jsonpath='{.spec.replicas}' 2>$null

}


function Get-AvailableReplicas {

    return kubectl get deployment/$deployment `
        -n $namespace `
        -o jsonpath='{.status.availableReplicas}' 2>$null

}



# ================= MESSUNG ====================================================


for ($i = 1; $i -le $runs; $i++) {


    Write-Host ""
    Write-Host "--- Durchgang $i von $runs ---" -ForegroundColor Cyan



    # --------------------------------------------------------------------------
    # Ausgangszustand herstellen
    # --------------------------------------------------------------------------


    kubectl scale deployment/$deployment `
        --replicas=$desiredReplicas `
        -n $namespace | Out-Null


    Write-Host "Warte auf Ausgangszustand..."


    while ($true) {

        $replicas = Get-Replicas
        $available = Get-AvailableReplicas


        if (
            ($replicas -eq "$desiredReplicas") -and
            ($available -eq "$desiredReplicas")
        ) {
            break
        }


        Start-Sleep -Milliseconds 500

    }



    Start-Sleep -Seconds 5



    # --------------------------------------------------------------------------
    # Drift erzeugen
    # --------------------------------------------------------------------------


    $T0 = [DateTimeOffset]::UtcNow


    kubectl scale deployment/$deployment `
        --replicas=$driftReplicas `
        -n $namespace | Out-Null


    Write-Host "Drift erzeugt: $desiredReplicas -> $driftReplicas"



    # --------------------------------------------------------------------------
    # MTTD
    # Warten bis Controller beginnt zu reparieren
    # --------------------------------------------------------------------------


    $detected = $false


    while (-not $detected) {


        Start-Sleep -Milliseconds $checkIntervalMs


        $replicas = Get-Replicas



        if (
            $replicas -and
            ([int]$replicas -lt $driftReplicas)
        ) {


            $Tdetect = [DateTimeOffset]::UtcNow

            $detected = $true


        }

    }



    Write-Host "Reparatur gestartet"



    # --------------------------------------------------------------------------
    # MTTR
    # Warten bis vollständig wiederhergestellt
    # --------------------------------------------------------------------------


    $recovered = $false


    while (-not $recovered) {


        Start-Sleep -Milliseconds $checkIntervalMs


        $replicas = Get-Replicas

        $available = Get-AvailableReplicas



        if (
            ($replicas -eq "$desiredReplicas") -and
            ($available -eq "$desiredReplicas")
        ) {


            $Tfinish = [DateTimeOffset]::UtcNow

            $recovered = $true

        }

    }



    # --------------------------------------------------------------------------
    # Berechnung
    # --------------------------------------------------------------------------


    $mttd = ($Tdetect - $T0).TotalSeconds
    $mttr = ($Tfinish - $T0).TotalSeconds


    $mttdList += $mttd
    $mttrList += $mttr



    Write-Host ""
    Write-Host "MTTD: $([math]::Round($mttd,3)) Sekunden"
    Write-Host "MTTR: $([math]::Round($mttr,3)) Sekunden"



    if ($i -lt $runs) {


        Write-Host ""
        Write-Host "Cooldown $cooldownSeconds Sekunden..." -ForegroundColor Gray


        Start-Sleep -Seconds $cooldownSeconds

    }

}



# ================= AUSWERTUNG =================================================


$avgMttd = ($mttdList | Measure-Object -Average).Average
$avgMttr = ($mttrList | Measure-Object -Average).Average



Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " ERGEBNIS" -ForegroundColor Yellow
Write-Host "============================================================"

Write-Host "Controller: $controller"
Write-Host "Durchläufe: $runs"

Write-Host ""
Write-Host "Durchschnittliche MTTD: $([math]::Round($avgMttd,3)) Sekunden"
Write-Host "Durchschnittliche MTTR: $([math]::Round($avgMttr,3)) Sekunden"

Write-Host ""
Write-Host "Einzelwerte:"
Write-Host ""

for ($i = 0; $i -lt $runs; $i++) {

    Write-Host "Run $($i+1): MTTD=$([math]::Round($mttdList[$i],3))s | MTTR=$([math]::Round($mttrList[$i],3))s"

}

Write-Host "============================================================"