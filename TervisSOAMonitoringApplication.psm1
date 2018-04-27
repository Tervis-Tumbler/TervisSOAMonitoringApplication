$ModulePath = (Get-Module -ListAvailable TervisSOAMonitoringApplication).ModuleBase

function Invoke-TervosOracleSOAJobMonitoringApplication {
    Invoke-TervosOracleSOAJobMonitoring -SOASchedulerURL $env:SOASchedulerURL -EmailTo $env:EmailTo -EmailFrom $env:EmailFrom
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

    Set-PSBreakpoint -Command Invoke-TervosOracleSOAJobMonitoringApplication
}
