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

		# print(keys)
		# print(np.array(nc_file.variables['bnds']))
		# print(np.array(nc_file.variables['lat_bnds']))
		# print(np.array(nc_file.variables['lon_bnds']))
		# break

		datetimes = np.array(nc_file.variables['TIME'])
		sifs = np.array(nc_file.variables['sif'])
		lats = np.array(nc_file.variables['lat'])
		lons = np.array(nc_file.variables['lon'])
		lat_bnds = np.array(nc_file.variables['lat_bnds'])
		lon_bnds = np.array(nc_file.variables['lon_bnds'])

		num_rows = len(datetimes)

		# Enter each record into the database

		t1 = time.time()

		# Insert rows one-by-one
		for i in range(num_rows):

			# Temporary cap of N inserts
			if ((i+1) % 32 == 0):
				print(str(i/num_rows * 100) + '% completed')
				break

			# Convert from utc to datetime
			date = datetime.utcfromtimestamp(datetimes[i]).strftime\
				('%Y-%m-%d %H:%M:%S')

			# Extract minimum bounding rectangle coordinates
			# reminder: lon corresponds to x, lat corresponds to y

			# top left corner
			mbr_tlc_lat = max(lat_bnds[:,i])	
			mbr_tlc_lon = min(lon_bnds[:,i])

			# bottom right corner
			mbr_brc_lat = min(lat_bnds[:,i])	
			mbr_brc_lon = max(lon_bnds[:,i])

			# Append to SQL statement
			cmd = 'CALL rtree_insert(\' %s \' , %s, %s, %s, %s, %s, %s, %s)' % \
					(date, sifs[i], lats[i], lons[i], \
					 mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon)
			print(cmd)
		
			cursor.execute(cmd)
			
		conn.commit()

		break

print('total elapsed time: ' + str(time.time() - t0))
