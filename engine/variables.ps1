[string]   $logoName              = 'ACME Co'                         # Your company name, used for report titles

[int]      $script:ccTasks        =   5                               # Number of concurrent tasks to perform (the higher the number the more resources you need)
[int]      $script:waitTime       = 100                               # Time to wait between starting new tasks (milliseconds)
[int]      $script:checkTimeout   =  60                               # Time to wait for each task to complete (seconds)
[string]   $script:qaOutput       = "$env:SystemDrive\QA\Results\"    # Report output location
[hashtable]$script:qaNotes        = @{}
[hashtable]$script:sections       = @{'acc' = 'Accounts';             #
                                      'com' = 'Compliance';            # 
                                      'drv' = 'Drives';                # List of sections, matched
                                      'hvh' = 'HyperV Host';           # with the check short name
                                      'net' = 'Network';               # 
                                      'reg' = 'Regional';              #
                                      'sec' = 'Security';              # These are displayed in
                                      'sys' = 'System';                # the HTML report file
                                      'vhv' = 'VMs - HyperV';          #
                                      'vmw' = 'VMs - VMware';         #
                                     }
#