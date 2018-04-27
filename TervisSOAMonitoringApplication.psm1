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
    docker build --no-cache -t tervissoamonitoringapplication $ModulePath
    docker build --no-cache -t testing $ModulePath
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
    docker run --env SOASchedulerURL='$SOASchedulerURL' --env EmailTo='$EmailTo' --env EmailFrom='$EmailFrom' --name soamon --volume $ModulePath/Dependencies:/usr/local/share/powershell/Modules tervissoamonitoringapplication
    docker run --tty --interactive --env TZ=America/New_York --name soamon --volume /Users/chrismagnuson/.local/share/powershell/Modules/:/usr/local/share/powershell/Modules microsoft/powershell
    docker run --tty --interactive --env TZ=America/New_York --name soamon --volume /Users/chrismagnuson/.local/share/powershell/Modules/:/usr/local/share/powershell/Modules testing
}

function Func {
    Invoke-TervisSOAMonitoringApplicationDockerRun 
    Invoke-TervosOracleSOAJobMonitoring -SOASchedulerURL http://soaweblogic.production.tervis.prv:7201/SOAScheduler/soaschedulerservlet?action=read -EmailTo cmagnuson@tervis.com -EmailFrom cmagnuson@tervis.com
}
