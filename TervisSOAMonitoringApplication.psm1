$ModulePath = (Get-Module -ListAvailable TervisSOAMonitoringApplication).ModuleBase

$SOAEnvironments = [PSCustomObject]@{
    Name = "Production"
    NotificationEmail = "SOAIssues@tervis.com"
    SOASchedulerURL = "http://soaweblogic.production.tervis.prv:7201/SOAScheduler/soaschedulerservlet?action=read"
    JobsThatShouldBeDisabled = "WarrantyOrderJob", "WebWarrantyJob", "WOMZRJob", "ImageIntJob"
}

function Invoke-TervosOracleSOAJobMonitoringApplication {
    param (
        $SOASchedulerURL = $env:SOASchedulerURL,
        $EmailTo = $env:EmailTo,
        $EmailFrom = $env:EmailFrom
    )
    Invoke-TervosOracleSOAJobMonitoring @PSBoundParameters
}

function Invoke-TervosOracleSOAJobMonitoringApplicationJsonParam {
    $ConfigurationParameters = Get-Content -Path $ModulePath/Parameters.json |
    ConvertFrom-Json |
    ConvertTo-HashTable

    Invoke-TervosOracleSOAJobMonitoring @ConfigurationParameters
}

function Invoke-TervisSOAMonitoringApplicationDockerBuild {
    $BuildDirectory = "$($env:TMPDIR)SOAMonitorngDocker"
    New-Item -ItemType Directory -Path $BuildDirectory -ErrorAction SilentlyContinue
    Invoke-PSDepend -Force -Install -InputObject @{
        PSDependOptions = @{
            Target = $BuildDirectory
        }
    
        'Tervis-Tumbler/TervisMailMessage' = 'master'
        'Tervis-Tumbler/TervisOracleSOASuite' = 'master'
        'Tervis-Tumbler/TervisSOAMonitoringApplication' = 'master'
    }

    Push-Location -Path $BuildDirectory

@"
**/.git
**/.vscode
"@ | Out-File -Encoding ascii -FilePath .dockerignore -Force

@"
FROM microsoft/powershell
ENV TZ=America/New_York
RUN echo `$TZ > /etc/timezone && \
    apt-get update && apt-get install -y tzdata && \
    rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/`$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean
COPY . /usr/local/share/powershell/Modules
#ENTRYPOINT ["pwsh", "-Command", "Invoke-TervosOracleSOAJobMonitoringApplication" ]
ENTRYPOINT ["pwsh"]
"@ | Out-File -Encoding ascii -FilePath .\Dockerfile -Force

    docker build --no-cache -t tervissoamonitoringapplication .

    Pop-Location

    Remove-Item -Path $BuildDirectory -Recurse -Force
}

function Remove-DockerContainerAllOff {
    docker rm $(docker ps -a -q)
}

function Get-DockerContainer {
    docker ps -a
}

function Invoke-TervisSOAMonitoringApplicationDockerRun {
    param (
        $SOASchedulerURL,
        $EmailTo,
        $EmailFrom
    )
@"
docker run --tty --interactive --env SOASchedulerURL="$SOASchedulerURL" --env EmailTo="$EmailTo" --env EmailFrom="$EmailFrom" --name soamon tervissoamonitoringapplication
"@


    #docker run --tty --interactive --env TZ=America/New_York --name soamon --volume /Users/chrismagnuson/.local/share/powershell/Modules/:/usr/local/share/powershell/Modules microsoft/powershell
    #docker run --tty --interactive --env TZ=America/New_York --name soamon --volume /Users/chrismagnuson/.local/share/powershell/Modules/:/usr/local/share/powershell/Modules testing
}

function Func {
    Invoke-TervisSOAMonitoringApplicationDockerRun -SOASchedulerURL http://soaweblogic.production.tervis.prv:7201/SOAScheduler/soaschedulerservlet?action=read -EmailTo cmagnuson@tervis.com -EmailFrom cmagnuson@tervis.com
    Invoke-TervosOracleSOAJobMonitoring -SOASchedulerURL http://soaweblogic.production.tervis.prv:7201/SOAScheduler/soaschedulerservlet?action=read -EmailTo cmagnuson@tervis.com -EmailFrom cmagnuson@tervis.com
    Invoke-InstallTervisSAMonitoringApplication -SOASchedulerURL http://soaweblogic.production.tervis.prv:7201/SOAScheduler/soaschedulerservlet?action=read -EmailTo cmagnuson@tervis.com -EmailFrom cmagnuson@tervis.com -ComputerName inf-tasks01

    Set-PSBreakpoint -Command Invoke-TervosOracleSOAJobMonitoringApplication

    $env:PSModulePath -split ":" | select -First 1 -Skip 1 | Set-Location
    
    docker tag 3f641a1e9573 tervis/tervissoamonitoringapplication:0.0.1
    docker push tervis/tervissoamonitoringapplication

    kubectl create -f ./SOAMonitor.yaml
    kubectl delete -f ./SOAMonitor.yaml
    kubectl proxy
    kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
    http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
}

function Invoke-InstallTervisSAMonitoringApplication {
    param (
        [Parameter(Mandatory)]$ComputerName
    )
    $ProgramData = "C:\ProgramData"
    $SOAMonitoringDirectoryLocal = "$ProgramData\Tervis\SOAMonitoring"
    $SOAMonitoringDirectoryRemote = $SOAMonitoringDirectoryLocal | ConvertTo-RemotePath -ComputerName $ComputerName
    Remove-Item -Path $SOAMonitoringDirectoryRemote -ErrorAction SilentlyContinue -Recurse -Force
    New-Item -ItemType Directory -Path $SOAMonitoringDirectoryRemote -ErrorAction SilentlyContinue
    Invoke-PSDepend -Force -Install -InputObject @{
        PSDependOptions = @{
            Target = $SOAMonitoringDirectoryRemote
        }
    
        'Tervis-Tumbler/TervisMailMessage' = 'master'
        'Tervis-Tumbler/TervisOracleSOASuite' = 'master'
        'Tervis-Tumbler/TervisSOAMonitoringApplication' = 'master'
    }
    $OFSBackup = $OFS
    $OFS = ""
@"
Get-ChildItem -Path $SOAMonitoringDirectoryLocal -Directory | 
ForEach-Object {
    Import-Module -Name `$_.FullName -Force
}

$(
    foreach ($SOAEnvironment in $SOAEnvironments) {
        "Invoke-TervosOracleSOAJobMonitoringApplication -SOASchedulerURL $($SOAEnvironment.SOASchedulerURL) -NotificationEmail $($SOAEnvironment.NotificationEmail) -EnvironmentName $($SOAEnvironment.Name) -JobsThatShouldBeDisabled $($SOAEnvironment.JobsThatShouldBeDisabled)"
    }
)
"@ |
    Out-File -FilePath $SOAMonitoringDirectoryRemote\Script.ps1
    
    $OFS = $OFSBackup

    $ScheduledTasksCredential = New-Object System.Management.Automation.PSCredential ("system", (new-object System.Security.SecureString))

    Install-PowerShellApplicationScheduledTask -PathToScriptForScheduledTask $SOAMonitoringDirectoryLocal\Script.ps1 `
        -TaskName "Invoke-TervosOracleSOAJobMonitoringApplication" `
        -Credential $ScheduledTasksCredential `
        -RepetitionInterval EveryDayEvery15Minutes `
        -ComputerName $ComputerName
}