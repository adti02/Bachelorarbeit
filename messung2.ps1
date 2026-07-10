# ============================================
# GitOps deklarative MTTD / MTTR Messung
# Argo CD / Flux CD Vergleich
#
# Messung:
# Git Push -> Controller erkennt Änderung (MTTD)
# Git Push -> Deployment fertig (MTTR)
# ============================================


# ================= KONFIGURATION =============

$controller = "argo"       # "argo" oder "flux"

$deployment = "meine-test-app"
$namespace = "default"


# Argo
$argoApplication = "test1"
$argoNamespace = "argocd"


# Flux
$gitRepository = "flux-system"
$fluxNamespace = "flux-system"



# ============================================

Write-Host ""
Write-Host "============================================"
Write-Host "GitOps deklarative Messung"
Write-Host "Controller: $controller"
Write-Host "============================================"



# ============================================
# Zustand vor Push speichern
# ============================================


if ($controller -eq "argo") {


    $old_revision = kubectl get application $argoApplication `
        -n $argoNamespace `
        -o jsonpath='{.status.sync.revision}'


    Write-Host "Alte Argo Revision:"
    Write-Host $old_revision

}



if ($controller -eq "flux") {


    $old_revision = kubectl get gitrepository $gitRepository `
        -n $fluxNamespace `
        -o jsonpath='{.status.artifact.revision}'


    Write-Host "Alte Flux Revision:"
    Write-Host $old_revision

}



# ============================================
# Git Änderung
# ============================================


Write-Host ""
Write-Host "Git Commit..."


git add .


git commit -m "Messung $(Get-Date)"



if ($LASTEXITCODE -ne 0) {

    Write-Host "Kein neuer Commit vorhanden"
    exit

}



# ============================================
# Push Start
# ============================================


$start_push = Get-Date


Write-Host ""
Write-Host "Push gestartet:"
Write-Host $start_push



git push origin main



if ($LASTEXITCODE -ne 0) {

    Write-Host "Git Push fehlgeschlagen"
    exit

}



Write-Host "Push abgeschlossen"



# ============================================
# MTTD
# Controller erkennt Änderung
# ============================================


Write-Host ""
Write-Host "Warte auf Controller Erkennung..."



while ($true) {


    if ($controller -eq "argo") {


        $new_revision = kubectl get application $argoApplication `
            -n $argoNamespace `
            -o jsonpath='{.status.sync.revision}'


    }



    if ($controller -eq "flux") {


        $new_revision = kubectl get gitrepository $gitRepository `
            -n $fluxNamespace `
            -o jsonpath='{.status.artifact.revision}'


    }



    if (
        ($new_revision) -and
        ($new_revision -ne $old_revision)
    ) {


        $mttd_end = Get-Date


        Write-Host ""
        Write-Host "Neue Revision erkannt:"
        Write-Host $new_revision


        break

    }



    Start-Sleep -Milliseconds 500

}



# ============================================
# MTTR
# Deployment bereit
# ============================================


Write-Host ""
Write-Host "Warte auf Deployment..."



kubectl rollout status deployment/$deployment `
    -n $namespace `
    --timeout=300s | Out-Null



$mttr_end = Get-Date



# ============================================
# Berechnung
# ============================================


$mttd = $mttd_end - $start_push

$mttr = $mttr_end - $start_push



Write-Host ""
Write-Host "============================================"
Write-Host "ERGEBNIS"
Write-Host "============================================"

Write-Host "Controller: $controller"

Write-Host ""
Write-Host "MTTD (Git -> erkannt): $([math]::Round($mttd.TotalSeconds,3)) Sekunden"

Write-Host "MTTR (Git -> Deployment Ready): $([math]::Round($mttr.TotalSeconds,3)) Sekunden"

Write-Host "============================================"