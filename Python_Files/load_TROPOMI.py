# Rupesh Jeyaram 
# Created April 6th, 2019

# Load all the TROPOMI data from the .nc files in SOURCE
# and import it into the specified local database 

# NetCDF docs: http://unidata.github.io/netcdf4-python/netCDF4/index.html

# Finding files in directory: https://stackoverflow.com/questions/3964681/find-
# all-files-in-a-directory-with-extension-txt-in-python

# Connecting to database: https://www.python.org/dev/peps/pep-0249/

SOURCE = '../TROPOMI_Data/'

import os						# For searching through files
import netCDF4 as nc 			# For parsing data format
import mysql.connector as dbapi # For connecting to database
from datetime import datetime 	# For converting unix time to SQL datetime
import time 					# For timing the insertion
import numpy as np 				# For accessing the data more efficiently


# Connect to database

conn = dbapi.connect(host='127.0.0.1', port=3306, user='root',
                         passwd='breakit', db='sys',
                         auth_plugin='mysql_native_password')

cursor = conn.cursor()

t0 = time.time()

# For each data file in the directory 
for file in sorted(os.listdir(SOURCE)):
	if file.endswith('.nc'):
		print(file)

		# Parse it

		nc_file = nc.Dataset(SOURCE + file, 'r')
		keys = nc_file.variables.keys()

		# Very important to convert to numpy array here!!
		# It takes orders of magnitude longer to use the 
		# native Dataset format

		datetimes = np.array(nc_file.variables['TIME'])
		sifs = np.array(nc_file.variables['sif'])
		lats = np.array(nc_file.variables['lat'])
		lons = np.array(nc_file.variables['lon'])

		num_rows = len(datetimes)

		# Enter each record into the database

		# Use this string to construct a batch insert SQL statement
		cmd = 'INSERT INTO tropomi VALUES '

		t1 = time.time()

		for i in range(num_rows):

			# Insert rows in chunks of 100,000 records
			if ((i+1) % 100000 == 0):
				print(str(i/num_rows * 100) + '% completed')

				cmd = cmd[:-2]
				print('time to parse rows: ' + str(time.time() - t1))

				t2 = time.time()
				cursor.execute(cmd)
				conn.commit()
				print('time to insert: ' + str(time.time() - t2))
				cmd = 'INSERT INTO tropomi VALUES '

				t1 = time.time()

			# Convert from utc to datetime
			date = datetime.utcfromtimestamp(datetimes[i]).strftime\
				('%Y-%m-%d %H:%M:%S')

			# Append to SQL statement
			cmd += '(NULL, \' %s \' , %s, %s, %s), ' % \
					(date, sifs[i], lats[i], lons[i])
		
		cursor.execute(cmd[:-2])
		conn.commit()

		break

print('total elapsed time: ' + str(time.time() - t0))
