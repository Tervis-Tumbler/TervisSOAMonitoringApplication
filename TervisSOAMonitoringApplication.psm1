$ModulePath = (Get-Module -ListAvailable TervisSOAMonitoringApplication).ModuleBase

function Invoke-TervosOracleSOAJobMonitoringApplication {
    Invoke-TervosOracleSOAJobMonitoring -SOASchedulerURL $env:SOASchedulerURL -EmailTo $env:EmailTo -EmailFrom $env:EmailFrom
}

function Invoke-TervisSOAMonitoringApplicationDockerBuild {
    New-Item -ItemType Directory -Path $ModulePath -Name Dependencies
    Invoke-PSDepend -Force -Install -InputObject @{
        PSDependOptions = @{
            Target = '$PWD/Dependencies'
        }
    
        'Tervis-Tumbler/TervisMailMessage' = 'master'
        'Tervis-Tumbler/TervisOracleSOASuite' = 'master'
        'Tervis-Tumbler/TervisSOAMonitoringApplication' = 'master'
    }
    docker build -t tervissoamonitoringa`pplication:latest $ModulePath
}

function Invoke-TervisSOAMonitoringApplicationDockerRun {
    param (
        $SOASchedulerURL,
        $EmailTo,
        $EmailFrom
    )
    docker run TervisSOAMonitoringApplication -e SOASchedulerURL='$SOASchedulerURL' -e EmailTo='$EmailTo' -e EmailFrom='$EmailFrom'
}

Invoke-TervisSOAMonitoringApplicationDockerRun -SOASchedulerURL http://soaweblogic.production.tervis.prv:7201/SOAScheduler/soaschedulerservlet?action=read -EmailTo cmagnuson@teris.com -EmailFrom cmagnuson@tervis.com