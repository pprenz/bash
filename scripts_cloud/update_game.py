#!/usr/bin/env python

import sys
import traceback 
import time
from datetime import datetime, timedelta

import pyodbc

def log(message):
    for line in message.split("\n"):
        line = line.rstrip()
        if line:
            print '[%s] %s' % (datetime.now().strftime('%Y-%m-%dT%H:%M:%S'), line) 

if len(sys.argv) < 2:
    today = datetime.now()
    if today.isoweekday() == 1: # Monday
        delta = timedelta(3) # back to friday
    else:
        delta = timedelta(1) # otherwise, yesterday
        
    year, month, day = (today - delta).timetuple()[0:3]
    date_id = '%02d-%02d-%02d' % (year, month, day)
else:
    date_id = sys.argv[1]
    
start_time = time.time()


connect_str = 'DSN=so1web-sept;UID=sof1;PWD=dbAdmin@so1'
conn = pyodbc.connect(connect_str)

try:
    cursor = conn.cursor()
    cursor.execute("execute game.UpdateGame ?", date_id)
except:
    conn.rollback()
    error_message = traceback.format_exc()
    log(error_message)
else:
    conn.commit()
    end_time = time.time() - start_time
    log('Generated %s game results in %.2f seconds' % (
        date_id, 
        end_time
    ))
finally:
    conn.close()


        