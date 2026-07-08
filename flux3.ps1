# ==============================================================================
# GITOPS MESS-SKRIPT FÜR FLUX CD
# Automatischer Drift-Test mit MTTD und MTTR
# ==============================================================================

# --- KONFIGURATION ---
$deployment = "meine-test-app"
$kustomization = "flux-system"
$fluxNamespace = "flux-system"
$runs = 5

# Git Soll-Zustand
$desiredReplicas = 3


# --- SPEICHER ---
$mttdList = @()
$mttrList = @()


# Namespace automatisch ermitteln
$namespace = kubectl get deployment $deployment --all-namespaces -o jsonpath='{.items[0].metadata.namespace}' 2>$null

if (-not $namespace) {
    $namespace = "default"
}


Clear-Host

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " FLUX CD DRIFT MESSUNG" -ForegroundColor Yellow
Write-Host " Deployment: $deployment" -ForegroundColor Yellow
Write-Host " Namespace: $namespace" -ForegroundColor Yellow
Write-Host " Durchläufe: $runs" -ForegroundColor Yellow
Write-Host "============================================================"


# Hilfsfunktion: Flux Ready Status lesen
function Get-FluxReady {

    $flux = kubectl get kustomization $kustomization `
        -n $fluxNamespace `
        -o json | ConvertFrom-Json


    $condition = $flux.status.conditions |
        Where-Object {$_.type -eq "Ready"}


    return $condition.status
}



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
    # Warten bis Flux reagiert
    # --------------------------------------------------------------------------

    Write-Host "Warte auf Flux Reaktion..."


    $detected = $false


    while (-not $detected) {


        Start-Sleep -Milliseconds 500


        $currentReplicas = kubectl get deployment/$deployment `
            -n $namespace `
            -o jsonpath='{.spec.replicas}' 2>$null



        # Flux hat begonnen zu korrigieren,
        # sobald der Wert nicht mehr 5 ist

        if ($currentReplicas -and ([int]$currentReplicas -lt 5)) {


            $T_detect = [DateTimeOffset]::UtcNow

            $detected = $true


            Write-Host "Flux Reaktion erkannt" -ForegroundColor Green
        }

    }



    # --------------------------------------------------------------------------
    # MTTR:
    # Warten bis Soll-Zustand wiederhergestellt
    # --------------------------------------------------------------------------

    Write-Host "Warte auf vollständige Wiederherstellung..."

    $recovered = $false


    while (-not $recovered) {


        Start-Sleep -Milliseconds 500


        $replicas = kubectl get deployment/$deployment `
            -n $namespace `
            -o jsonpath='{.spec.replicas}' 2>$null


        $ready = Get-FluxReady



        if (($replicas -eq "$desiredReplicas") -and ($ready -eq "True")) {


            $T_finish = [DateTimeOffset]::UtcNow


            $recovered = $true


            Write-Host "Flux Wiederherstellung abgeschlossen" -ForegroundColor Green

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
Write-Host " FLUX MESSERGEBNIS" -ForegroundColor Yellow
Write-Host "============================================================"

Write-Host "Durchläufe: $runs"
Write-Host "Durchschnittliche MTTD: $([math]::Round($avgMttd,2)) Sekunden"
Write-Host "Durchschnittliche MTTR: $([math]::Round($avgMttr,2)) Sekunden"

Write-Host "============================================================"