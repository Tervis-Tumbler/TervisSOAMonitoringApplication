$ModulePath = (Get-Module -ListAvailable TervisSOAMonitoringApplication).ModuleBase


function Invoke-TervisSOAMonitoringApplicationDockerBuild {
    Invoke-PowerShellApplicationDockerBuild -ModuleName TervisSOAMonitoringApplication -DependentTervisModuleNames "TervisMailMessage","TervisOracleSOASuite" -CommandsString "Invoke-TervisOracleSOAJobMonitoring"
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
}

function Install-TervisSAMonitoringApplication {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        $OFSBackup = $OFS
        $OFS = ""

        $ScheduledScriptCommandsString = @"
$(
    foreach ($SOAEnvironment in (Get-SOAEnvironment)) {
        "Invoke-TervisOracleSOAJobMonitoring -SOASchedulerURL $($SOAEnvironment.SOASchedulerURL) -NotificationEmail $($SOAEnvironment.NotificationEmail) -EnvironmentName $($SOAEnvironment.Name)
    }
)
"@        
        $OFS = $OFSBackup
        
        $ScheduledTasksCredential = New-Object System.Management.Automation.PSCredential ("system", (new-object System.Security.SecureString))

        $InstallPowerShellApplicationParameters = @{
            ModuleName = "TervisSOAMonitoringApplication"
            DependentTervisModuleNames = "TervisMailMessage","TervisOracleSOASuite"
            ScheduledScriptCommandsString = $ScheduledScriptCommandsString
            ScheduledTasksCredential = $ScheduledTasksCredential
            SchduledTaskName = "Invoke-TervisOracleSOAJobMonitoring"
            RepetitionIntervalName = "EveryDayEvery15Minutes"
        }
    
        Install-PowerShellApplication -ComputerName $ComputerName @InstallPowerShellApplicationParameters
    }
}

function Test-TervisSOAMonitoringApplication {
    Invoke-TervisSOAMonitoringApplicationDockerRun -SOASchedulerURL http://soaweblogic.production.tervis.prv:7201/SOAScheduler/soaschedulerservlet?action=read -EmailTo cmagnuson@tervis.com -EmailFrom cmagnuson@tervis.com
    Invoke-TervisOracleSOAJobMonitoring  -SOASchedulerURL http://soaweblogic.production.tervis.prv:7201/SOAScheduler/soaschedulerservlet?action=read -EmailTo cmagnuson@tervis.com -EmailFrom cmagnuson@tervis.com
    Invoke-InstallTervisSAMonitoringApplication -SOASchedulerURL http://soaweblogic.production.tervis.prv:7201/SOAScheduler/soaschedulerservlet?action=read -EmailTo cmagnuson@tervis.com -EmailFrom cmagnuson@tervis.com -ComputerName inf-tasks01

    Set-PSBreakpoint -Command Invoke-TervisOracleSOAJobMonitoring 

    $env:PSModulePath -split ":" | select -First 1 -Skip 1 | Set-Location
    
    docker tag 3f641a1e9573 tervis/tervissoamonitoringapplication:0.0.1
    docker push tervis/tervissoamonitoringapplication

    kubectl create -f ./SOAMonitor.yaml
    kubectl delete -f ./SOAMonitor.yaml
    kubectl proxy
    kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
    http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
}