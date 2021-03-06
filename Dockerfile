FROM microsoft/powershell
ENV TZ=America/New_York
RUN echo $TZ > /etc/timezone && \
    apt-get update && apt-get install -y tzdata && \
    rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean
COPY ./Dependencies /usr/local/share/powershell/Modules
ENTRYPOINT ["pwsh", "-Command", "Invoke-TervosOracleSOAJobMonitoringApplication" ]