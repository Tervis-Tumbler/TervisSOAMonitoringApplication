FROM microsoft/powershell
COPY ./Dependencies /usr/local/share/powershell/Modules
ENTRYPOINT ["pwsh"]
CMD [ "-c", "{ Invoke-TervosOracleSOAJobMonitoringApplication }" ]