# Rupesh Jeyaram 
# Created April 6th, 2019

# Load all the TROPOMI data from the .nc files in SOURCE
# and import it into the specified local database 

# NetCDF docs: http://unidata.github.io/netcdf4-python/netCDF4/index.html

# Finding files in directory: https://stackoverflow.com/questions/3964681/find-
# all-files-in-a-directory-with-extension-txt-in-python

# Connecting to database: https://www.python.org/dev/peps/pep-0249/
# https://dev.mysql.com/doc/connector-python/en/connector-python-example-
# cursor-select.html
#
# How to run a SQL script from python (very straightforward)
# https://www.quora.com/How-can-I-execute-a-sql-file-in-Python

SOURCE = '../TROPOMI_Data/'

import os						# For searching through files
import netCDF4 as nc 			# For parsing data format
import mysql.connector as dbapi # For connecting to database
from datetime import datetime 	# For converting unix time to SQL datetime
import time 					# For timing the insertion
import numpy as np 				# For accessing the data more efficiently

# For creating images from rectangles
import matplotlib.pyplot as plt
from matplotlib.collections import PatchCollection
from matplotlib.patches import Rectangle
from PIL import Image
import imageio
import glob
import re

# Toggle animation generation
ANIMATE = False

# For generating rectangles on image

max_length = 360
max_height = 180

NUM_TO_INSERT = 5000

rect_num = 0

im = np.array(Image.open('../Images/base.jpg'), dtype=np.uint8)

fig, ax = plt.subplots()

colors = ['b', 'r', 'g']

# Connect to database

conn = dbapi.connect(host='127.0.0.1', port=3306, user='root',
                         passwd='breakit', db='sys',
                         auth_plugin='mysql_native_password')

cursor = conn.cursor()



# Different commands to run

make_tables_cmd = 'mysql --host=127.0.0.1 --user=root --password=breakit \
				   --database=sys \
				   -e \"source ../SQL_Files/make_TROPOMI_tables.sql\"'

make_inserts_cmd = 'mysql --host=127.0.0.1 --user=root --password=breakit \
				   --database=sys \
				   -e \"source ../SQL_Files/make_TROPOMI_insert.sql\"'

make_inserts_variants = 'mysql --host=127.0.0.1 --user=root --password=breakit \
				   --database=sys \
				   -e \"source ../SQL_Files/Insertion_Variants/'

vertical_splits = 'make_TROPOMI_insert_vertical.sql\"'
horizontal_splits = 'make_TROPOMI_insert_horizontal.sql\"'
constant_splits = 'make_TROPOMI_insert_constant.sql\"'
half_splits = 'make_TROPOMI_insert_half.sql\"'
gs_splits = 'make_TROPOMI_insert_graham_scan.sql\"'

# This function saves an image of the geometries at the current state
def save_geom_im(save_name='', dpi=100):

	global rect_num

	# query to get all rectangles after insert
	query = '(SELECT mbr_tlc_lat, mbr_tlc_lon, \
					mbr_brc_lat, mbr_brc_lon, level, 1 \
			 FROM \
			 entry_geom NATURAL JOIN leaf_node_entries) UNION \
			 (SELECT mbr_tlc_lat, mbr_tlc_lon, \
					mbr_brc_lat, mbr_brc_lon, level, 1 \
			 FROM \
			 entry_geom NATURAL JOIN inner_node_entries);'

	# query = "SELECT mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon, \
	# 		 level, SIF  FROM (entry_geom NATURAL JOIN leaf_node_entries) \
	# 		 NATURAL JOIN tropomi;"

	#print("Executing query...")

	# execute get-query
	cursor.execute(query)

	# build rectangles array
	rectangles = []
	for (tlc_lat, tlc_lon, brc_lat, brc_lon, length, SIF) in cursor :
		rectangles.append([float(tlc_lat), float(tlc_lon), 
						  float(brc_lat), float(brc_lon), 
						  int(length), float(SIF)])

	# list -> np.array
	rectangles = np.array(rectangles)

	#print("Finished executing query!")

	i = 0

	for r in rectangles:
		curr_len = r[3] - r[1]
		curr_height = r[0] - r[2]

		SIF = r[5]

		c = 0

		if SIF < 0.15:
			c = "#E4F2CF"
		elif SIF < 0.3:
			c = "#C6E9B0"
		elif SIF < 0.45:
			c = "#A1DF91"
		elif SIF < 0.6:
			c = "#C6E9B0"
		elif SIF < 0.75:
			c = "#75D573"
		elif SIF < 0.9:
			c = "#39BE67"
		else:
			c = "#1DB16C"

		rect = Rectangle((r[1] + 180 , 180 - (r[2] + 90) - curr_height), 
			curr_len, curr_height, fill = False, linewidth = 0.5, 
			color = colors[int(r[4])])
		ax.add_patch(rect)

		if i % 10000 == 0:
			print(i)

		i = i + 1

	plt.imshow(im)

	if (save_name == ''):
		plt.savefig('rect{}.png'.format(rect_num), dpi = dpi)
	else:
		plt.savefig(save_name, dpi = dpi)

	rect_num += 1
	
	[p.remove() for p in reversed(ax.patches)]

	conn.commit()

# https://stackoverflow.com/questions/5967500/how-to-correctly-sort-a-
# string-with-a-number-inside
def atoi(text):
    return int(text) if text.isdigit() else text
def natural_keys(text):
    return [ atoi(c) for c in re.split(r'(\d+)', text) ]

def run_insertions():

	# List to store runtimes
	times = []

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
			lat_bnds = np.array(nc_file.variables['lat_bnds'])
			lon_bnds = np.array(nc_file.variables['lon_bnds'])

			num_rows = len(datetimes)

			# Randomize the order

			permutation = np.random.permutation(num_rows)
			datetimes = datetimes[permutation]
			sifs = sifs[permutation]
			lats = lats[permutation]
			lons = lons[permutation]
			lat_bnds = np.take(lat_bnds, permutation, axis = 1) 
			lon_bnds = np.take(lon_bnds, permutation, axis = 1) 

			# Enter each record into the database

			# Insert rows one-by-one
			for i in range(num_rows):

				t1 = time.time()

				# Temporary cap of N inserts
				if ((i+1) % (NUM_TO_INSERT + 1) == 0):
					print(str(i/num_rows * 100) + '% completed')
					print('total: ', num_rows)
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
				cmd = 'CALL rtree_insert(\' %s \' , %s, %s, %s, %s, %s)' % \
						(date, sifs[i], \
						 mbr_tlc_lat, mbr_tlc_lon, mbr_brc_lat, mbr_brc_lon)

				if i % 100 == 0:
					print(str(i) + ": " + cmd + ";")
				# print(cmd + ";")
			
				# execute insert
				cursor.execute(cmd)

				times.append(time.time() - t1)

				if (ANIMATE):
					save_geom_im()
			
			times = np.array(times)

			conn.commit()

			return times

def gif_from_rects():
	print("Rendering gif...")

	images = sorted(glob.glob("rect*.png"), key = natural_keys)
	mim_images = []
	for f in images:
		mim_images.append(imageio.imread(f))
	imageio.mimsave('evolution.gif', mim_images)

	os.system("rm rect*.png")

def run(insert_def_file_cmd, save_file):
	os.system(make_tables_cmd)
	os.system(insert_def_file_cmd)

	t0 = time.time()
	times = run_insertions()
	print('time to insert: ' + str(time.time() - t0))
	save_geom_im(save_name=save_file)

	return times




# times1 = run(make_inserts_cmd, 'normal_split.png')
# times4 = run(make_inserts_variants + constant_splits, 'constant_split.png')
times5 = run(make_inserts_variants + half_splits, 'half_split.png')
times6 = run(make_inserts_variants + gs_splits, 'gs_split.png')
# gif_from_rects()
# os.system(make_tables_cmd)
# os.system(make_inserts_variants + vertical_splits)
# times2 = run_insertions()
# save_geom_im(save_name='vertical_split.png')

# os.system(make_tables_cmd)
# os.system(make_inserts_variants + horizontal_splits)
# times3 = run_insertions()
# save_geom_im(save_name='horizontal_split.png')

# os.system(make_tables_cmd)
# os.system(make_inserts_variants + constant_splits)
# times4 = run_insertions()
# save_geom_im(save_name='constant_split.png')

# os.system(make_tables_cmd)
# os.system(make_inserts_variants + half_splits)
# t0 = time.time()
# times5 = run_insertions()
# print('time to insert: ' + str(time.time() - t0))
# save_geom_im(save_name='half_split.png')



plt.clf()
fig, ax = plt.subplots()
# plt.scatter(np.arange(len(times1)), times1, s=5)
plt.scatter(np.arange(0), [], s=5)
plt.scatter(np.arange(0), [], s=5)
plt.scatter(np.arange(0), [], s=5)
plt.scatter(np.arange(0), [], s=5)
# plt.scatter(np.arange(0), [], s=5)
# plt.scatter(np.arange(len(times2)), times2, s=5)
# plt.scatter(np.arange(len(times3)), times3, s=5)
# plt.scatter(np.arange(len(times4)), times4, s=5)
plt.scatter(np.arange(len(times5)), times5, s=5)
plt.scatter(np.arange(len(times6)), times6, s=5)
ax.set_ylabel('Time (s)')
ax.set_xlabel('Element #')
ax.legend(['normal_split', 
	'vertical_split_constant', 
	'horizontal_split_constant', 
	'switched_sql_command', 
	'half_cross_join',
	'gs_split'])
plt.show()


