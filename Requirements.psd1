@{
    PSDependOptions = @{
        Target = '$PWD/Dependencies'
        AddToPath = $True            # I want to prepend project to $ENV:Path and $ENV:PSModulePath
    }

    # Clone a git repo
    'Tervis-Tumbler/TervisMailMessage' = 'master'
}