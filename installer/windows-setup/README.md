# Instalador do Windows

O GoLiveBypass oficial para Windows é só portable (`GoLiveBypass-x.y.z.exe`). Isso traz três problemas:

- o exe fica onde foi baixado (geralmente `Downloads`), sem atalho no menu Iniciar e sem desinstalador;
- a opção "Iniciar com Windows" usa a chave `Run` do registro, e no portable ela nem sempre é executada no boot. O app não abre, e com ele não abrem o bypass nem o Discord;
- a cada boot o portable se extrai de novo no `%TEMP%`.

O `GoLiveBypass-Setup-x.y.z.exe` resolve os dois primeiros sem recompilar o app:

| O quê | Como |
| --- | --- |
| Pasta fixa | `%LOCALAPPDATA%\Programs\GoLiveBypass\GoLiveBypass.exe`, por usuário e sem administrador |
| Atalhos | Menu Iniciar e, se marcado, área de trabalho |
| Desinstalar | Aparece em Configurações > Aplicativos instalados |
| Iniciar com o Windows | Tarefa agendada `GoLiveBypass` no logon, 20 s depois de entrar, com `--hidden`. O app sobe na bandeja; se o bypass estava ligado, ele religa e abre o Discord. As entradas `Run` antigas do GoLiveBypass são removidas para o app não abrir duas vezes. |
| Atualizações | O exe instalado é o portable oficial, então o updater embutido continua trocando o arquivo no mesmo lugar. A instalação recebe as versões novas sozinha. |

Configurações, sessão Proton e logs (`%LOCALAPPDATA%\GoLiveBypass`) são os mesmos do portable: quem já usava continua com tudo como estava. A desinstalação mantém essa pasta.

**Depois de instalar, deixe desmarcada a opção "Iniciar com Windows" dentro do app.** Ela grava a chave `Run` de novo, e o app abriria duas vezes no logon. Para desligar a inicialização, rode o instalador outra vez sem marcar a opção ou desative a tarefa `GoLiveBypass` no Agendador de Tarefas.

O UAC continua aparecendo no boot: o WireSock precisa de administrador para criar o túnel. A tarefa roda sem privilégio elevado de propósito, senão o Discord também abriria como administrador.

## Gerar

Precisa do NSIS 3 (`winget install NSIS.NSIS`).

```powershell
.\installer\windows-setup\build-setup.ps1                 # última release estável oficial
.\installer\windows-setup\build-setup.ps1 -Tag v2.0.18    # release específica
```

O script baixa `GoLiveBypass-x.y.z.exe` da release, confere o SHA-256 que a API do GitHub publica e gera `installer/windows-setup/dist/GoLiveBypass-Setup-x.y.z.exe`.

O workflow `.github/workflows/windows-setup.yml` faz o mesmo uma vez por dia e publica o instalador numa release `setup-vx.y.z` deste repositório quando sai versão estável nova.

Instalação silenciosa: `GoLiveBypass-Setup-x.y.z.exe /S` (pasta: `/D=C:\caminho`, sempre por último).
