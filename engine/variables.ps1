[string]   $logoName              = 'ATOS'                            # Your company name, used for report titles

[int]      $script:ccTasks        =   5                               # Number of concurrent tasks to perform (the higher the number the more resources you need)
[int]      $script:waitTime       = 100                               # Time to wait between starting new tasks (milliseconds)
[int]      $script:checkTimeout   =  60                               # Time to wait for each task to complete (seconds)
[string]   $script:qaOutput       = "$env:SystemDrive\QA\Results\"    # Report output location
[hashtable]$script:lang           = @{}                               # Holds language strings
[hashtable]$script:qahelp         = @{}                               # Holds help text for the HTML report