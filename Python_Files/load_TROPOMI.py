# Rupesh Jeyaram 
# Created April 6th, 2019

# Load all the TROPOMI data from the .nc files in SOURCE
# and import it into the specified local database 

# NetCDF docs: https://docs.scipy.org/doc/scipy-0.16.1/reference/generated/scipy
# .io.netcdf.netcdf_file.html

# Finding files in directory: https://stackoverflow.com/questions/3964681/find-
# all-files-in-a-directory-with-extension-txt-in-python

# Connecting to database: https://www.python.org/dev/peps/pep-0249/

SOURCE = '../TROPOMI_Data/'

import os						# For searching through files
import netCDF4 as nc 			# For parsing data format
import mysql.connector as dbapi # For connecting to database
from datetime import datetime 	# For converting unix time to SQL datetime
import time 					# For timing the insertion


# Connect to database

conn = dbapi.connect(host='127.0.0.1', port=3306, user='root',
                         passwd='breakit', db='sys',
                         auth_plugin='mysql_native_password')

cursor = conn.cursor()

t = time.time()

# For each data file in the directory 
for file in sorted(os.listdir(SOURCE)):
	if file.endswith('.nc'):
		print(file)

		# Parse it

		nc_file = nc.Dataset(SOURCE + file)
		keys = nc_file.variables.keys()

		datetimes = nc_file.variables['TIME']
		sifs = nc_file.variables['sif']
		lats = nc_file.variables['lat']
		lons = nc_file.variables['lon']

		num_rows = len(datetimes)

		# And enter each record into the database

		for i in range(num_rows):

			if (i % 100000 == 0):
				print(str(i/num_rows * 100) + '%')

			utc_date = datetimes[i]

			date = datetime.utcfromtimestamp(utc_date).strftime\
				('%Y-%m-%d %H:%M:%S')

			sif = str(sifs[i])
			lat = str(lats[i])
			lon = str(lons[i])

			cmd = "INSERT INTO tropomi VALUES (NULL, \'" + str(date) + "\', " + sif + \
												", " + lat + ", " + lon + ")"
			cursor.execute(cmd)


print("elapsed time: " + str(time.time() - t))

conn.commit()