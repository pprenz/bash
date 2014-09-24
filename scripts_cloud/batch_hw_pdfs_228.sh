#!/bin/bash

ssh -i /root/.ssh/so1web_so1cloud_rsa so1web@cloud1.schoolofone.net "cd /home/so1web/deployed/portal && source etc/so1web_env.sh && export SO1ENV=prod && python bin/so1batcher --school_id 2 --upload True --partial True --batch_type homework --overwrite $1 $2"
