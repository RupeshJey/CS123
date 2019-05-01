# Rupesh Jeyaram 
# Created April 30th 2019
# This is meant as a general test for visualizing the database's 
# rtree data structure. 

# gif generation: 
# https://matplotlib.org/api/_as_gen/matplotlib.animation.FuncAnimation.html
# https://matplotlib.org/api/_as_gen/matplotlib.patches.Patch.html#matplotlib.patches.Patch.set_color

# Had to install imagemagick

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.collections import PatchCollection
from matplotlib.patches import Rectangle
from PIL import Image
from matplotlib.animation import FuncAnimation

# Create Array of geometric entries

colors = ['b', 'r', 'g', 'm', 'k']

level_counts = np.array([10000, 1000, 100, 10, 1])

total = np.sum(level_counts)

entry_geom = np.zeros((total, len(level_counts))); 

max_length = 360
max_height = 180

im = np.array(Image.open('../Images/base.jpg'), dtype=np.uint8)


fig, ax = plt.subplots()

j = 0
i = 0

curr_level = level_counts[0]

for level in level_counts:

	curr_length = max_length / level
	curr_height = max_height / level

	for _ in range(level):

		rand_x = np.random.uniform(0, max_length - curr_length)
		rand_y = np.random.uniform(0, max_height - curr_height)

		entry_geom[j] = np.array([j, rand_x, rand_y + curr_height, rand_x + curr_length, rand_y])

		j = j + 1

	i = i + 1



def update(k):

	if (k == 0):
		[p.remove() for p in reversed(ax.patches)]

	k = total - 10800 - k

	if (k % 100 == 1):
		print(k)

	if k == 1:
		c = colors[4]
		curr_length = max_length / 1
		curr_height = max_height / 1
	elif k <= 11:
		c = colors[3]
		curr_length = max_length / 10
		curr_height = max_height / 10
	elif k <= 111:
		c = colors[2]
		curr_length = max_length / 100
		curr_height = max_height / 100
	elif k <= 1111:
		c = colors[1]
		curr_length = max_length / 1000
		curr_height = max_height / 1000
	else:
		c = colors[0]
		curr_length = max_length / 10000
		curr_height = max_height / 10000

	
	rect = Rectangle((entry_geom[k][1], entry_geom[k][2] - curr_height), curr_length, curr_height, fill = False, color = c)
	ax.add_patch(rect)
	ax.set_xlabel(k)
	return ax

anim = FuncAnimation(fig, update, frames=np.arange(0, total - 10800), interval=10)
# anim.save('mapping.gif', dpi=300, writer='imagemagick')

print(entry_geom)
plt.imshow(im)
plt.show()
