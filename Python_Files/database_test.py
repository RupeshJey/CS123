# Note: Needed to use mysql-connector-python instead of mysql-connector
# Also needed to find the proper db name, 'sys' when I thought it would
# be 'CS123_Database'

# Also needed to commit, which was cool -- atomicity!. 

import sys
import mysql.connector as dbapi

conn = dbapi.connect(host='127.0.0.1', port=3306, user='root',
                         passwd='breakit', db='sys',
                         auth_plugin='mysql_native_password')

cursor = conn.cursor()

cursor.execute("INSERT INTO tropomi VALUES (NULL, NOW(), 1.1, 1.2, 1.3)")

conn.commit()

# record_id       INTEGER             AUTO_INCREMENT PRIMARY KEY ,
# time               DATETIME           NOT NULL,
# SIF                VARCHAR(10)      NOT NULL,
# lat                  VARCHAR(20)      NOT NULL,
# lon                 VARCHAR(20)      NOT NULL