#!/usr/bin/env python

import sys
import traceback 
import time
from datetime import datetime, timedelta
from optparse import OptionParser
import pyodbc

def log(message):
    for line in message.split("\n"):
        line = line.rstrip()
        if line:
            print '[%s] %s' % (datetime.now().strftime('%Y-%m-%dT%H:%M:%S'), line) 

def default_date_to_update():
    today = datetime.now()
    if today.isoweekday() == 1: # Monday
        delta = timedelta(3) # back to friday
    else:
        delta = timedelta(1) # otherwise, yesterday
        
    year, month, day = (today - delta).timetuple()[0:3]
    date_id = '%02d-%02d-%02d' % (year, month, day)
    return date_id

parser = OptionParser()
parser.add_option("--date", action="store", type="string", dest="date_to_update", default=default_date_to_update())
parser.add_option("--attendance", action="store_true", dest="attendance", default=False)
parser.add_option("--grades", action="store_true", dest="grades", default=False)
parser.add_option("--game", action="store_true", dest="game", default=False)

(options, args) = parser.parse_args()

date_id = options.date_to_update
    
start_time = time.time()

connect_str = 'DSN=so1web-sept;UID=sof1;PWD=dbAdmin@so1'
conn = pyodbc.connect(connect_str)

try:
    cursor = conn.cursor()
    if options.attendance:
        cursor.execute("execute portal.UpdateAttendance ?", date_id)
    if options.grades:
        cursor.execute("execute portal.UpdateStudentGradesByDay ?", date_id)
    if options.game:
        cursor.execute("execute game.UpdateGame ?", date_id)
except:
    conn.rollback()
    error_message = traceback.format_exc()
    log(error_message)
else:
    conn.commit()
    end_time = time.time() - start_time
    log('Updated materialized views for %s in %.2f seconds' % (
        date_id, 
        end_time
    ))
finally:
    conn.close()


        