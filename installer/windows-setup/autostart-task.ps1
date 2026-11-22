# Tarefa agendada que abre o GoLiveBypass no logon do usuario.
#
# Por que tarefa agendada e nao a chave Run: no portable a entrada Run nem sempre e
# executada no boot (21-22/11/2026: tres boots seguidos sem o app abrir, com a entrada
# correta no registro). O Agendador de Tarefas tem atraso configuravel, historico
# ("Ultimo resultado") e nao depende da fila de apps de inicializacao do Explorer.
#
# A tarefa roda como o proprio usuario, sem privilegio elevado (o app pede o UAC
# sozinho so para o WireSock), e com --hidden: o app sobe na bandeja, religa o bypass
# se ele estava ligado e reabre o Discord no fim da ativacao.
param(
  [Parameter(Mandatory = $true)][ValidateSet("install", "remove")][string]$Action,
  [string]$Exe = "",
  [string]$TaskName = "GoLiveBypass",
  [switch]$KeepRun
)

$ErrorActionPreference = "Stop"

$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$User = "$env:USERDOMAIN\$env:USERNAME"

# Remove as entradas Run que abrem o GoLiveBypass (o toggle "Iniciar com Windows" do
# app grava "GoLiveBypass"; versoes antigas gravaram com outros nomes). Sem isso o app
# abriria duas vezes no logon e a segunda copia mostraria a janela.
function Remove-RunEntries {
  $props = Get-ItemProperty -Path $RunKey -ErrorAction SilentlyContinue
  if (-not $props) { return }
  foreach ($p in $props.PSObject.Properties) {
    if ($p.Name -like "PS*") { continue }
    $value = [string]$p.Value
    $target = if ($value -match '^"([^"]+)"') { $Matches[1] } else { ($value.Trim() -split '\s+')[0] }
    $leaf = Split-Path -Leaf $target
    if ($p.Name -eq "GoLiveBypass" -or $leaf -match '^golivebypass.*\.exe$') {
      Remove-ItemProperty -Path $RunKey -Name $p.Name -ErrorAction SilentlyContinue
    }
  }
}

try {
  if ($Action -eq "install") {
    if (-not $Exe -or -not (Test-Path -LiteralPath $Exe)) { throw "Executavel nao encontrado: $Exe" }
    if (-not $KeepRun) { Remove-RunEntries }
    $taskAction = New-ScheduledTaskAction -Execute $Exe -Argument "--hidden" -WorkingDirectory (Split-Path -Parent $Exe)
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
    # Espera a rede e a bandeja subirem antes de ativar o tunel.
    $trigger.Delay = "PT20S"
    $principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Limited
    # ExecutionTimeLimit zero: o padrao (72 h) mataria o app com o PC ligado por dias.
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
      -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -StartWhenAvailable
    Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $trigger -Principal $principal `
      -Settings $settings -Description "Abre o GoLiveBypass na bandeja ao entrar no Windows (religa o bypass e abre o Discord)." `
      -Force | Out-Null
  } else {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    if (-not $KeepRun) { Remove-RunEntries }
  }
  exit 0
} catch {
  Write-Output $_.Exception.Message
  exit 1
}
