# -*- coding: utf-8 -*-
#
# This file is part of pyunicorn.
# Copyright (C) 2008--2015 Jonathan F. Donges and pyunicorn authors
# URL: <http://www.pik-potsdam.de/members/donges/software>
# License: BSD (3-clause)


cimport cython
from cpython cimport bool
from libc.math cimport sqrt, floor
from libc.stdlib cimport rand, RAND_MAX


import numpy as np
cimport numpy as np
import numpy.random as rd
import random

randint = rd.randint



BOOLTYPE = np.uint8
INTTYPE = np.int
INT8TYPE = np.int8
INT16TYPE = np.int16
INT32TYPE = np.int32
FLOATTYPE = np.float
FLOAT32TYPE = np.float32
FLOAT64TYPE = np.float64
ctypedef np.uint8_t BOOLTYPE_t
ctypedef np.int_t INTTYPE_t
ctypedef np.int8_t INT8TYPE_t
ctypedef np.int16_t INT16TYPE_t
ctypedef np.int32_t INT32TYPE_t
ctypedef np.float_t FLOATTYPE_t
ctypedef np.float32_t FLOAT32TYPE_t
ctypedef np.float64_t FLOAT64TYPE_t

cdef extern from "stdlib.h":
    double drand48()

cdef extern from "stdlib.h":
    double srand48()

cdef extern from "time.h":
    double time()


# surrogates ==================================================================


def _embed_time_series_array(
    int N, int n_time, int dimension, int delay,
    np.ndarray[FLOATTYPE_t, ndim=2] time_series_array,
    np.ndarray[FLOAT64TYPE_t, ndim=3] embedding):
    """
    >>> 42 == 42
    True
    """

    cdef int i, j, k, max_delay, len_embedded, index

    # Calculate the maximum delay
    max_delay = (dimension - 1) * delay
    # Calculate the length of the embedded time series
    len_embedded = n_time - max_delay

    for i in xrange(N):
        for j in xrange(dimension):
            index = j*delay
            for k in xrange(len_embedded):
                embedding[i, k, j] = time_series_array[i, index]
                index += 1


def _recurrence_plot(
    int n_time, int dimension, float threshold,
    np.ndarray[FLOATTYPE_t, ndim=2] embedding,
    np.ndarray[INT8TYPE_t, ndim=2] R):

    cdef:
        int j, k, l
        double diff

    for j in xrange(n_time):
        # Ignore the main diagonal, since every sample is neighbor of itself
        for k in xrange(j):
            for l in xrange(dimension):
                # Use supremum norm
                diff = embedding[j, l] - embedding[k, l]

                if abs(diff) > threshold:
                    # j and k are not neighbors
                    R[j, k] = R[k, j] = 0

                    # Leave the loop
                    break


def _twins(
    int N, int n_time, int dimension, float threshold, int min_dist,
    np.ndarray[FLOATTYPE_t, ndim=3] embedding_array,
    np.ndarray[FLOATTYPE_t, ndim=2] R, np.ndarray[FLOATTYPE_t, ndim=1] nR,
    twins):

    cdef:
        int i, j, k, l
        double diff

    for i in xrange(N):
        # Initialize the recurrence matrix R and nR

        for j in xrange(n_time):
            for k in xrange(j+1):
                R[j, k] = R[k, j] = 1
            nR[j] = n_time

        # Calculate the recurrence matrix for time series i

        for j in xrange(n_time):
            # Ignore main diagonal, since every sample is neighbor of itself
            for k in xrange(j):
                for l in xrange(dimension):
                    # Use maximum norm
                    diff = embedding_array[i, j, l] - embedding_array[i, k, l]

                    if abs(diff) > threshold:
                        # j and k are not neighbors
                        R[j, k] = R[k, j] = 0

                        # Reduce neighbor count of j and k by one
                        nR[j] -= 1
                        nR[k] -= 1

                        # Leave the for loop
                        break

        # Add list for twins in time series i
        twins.append([])

        # Find all twins in the recurrence matrix

        for j in xrange(n_time):
            twins_i = twins[i]
            twins_i.append([])
            twins_ij = twins_i[j]

            # Respect a minimal temporal spacing between twins to avoid false
            # twins due to the higher
            # sample density in phase space along the trajectory
            for k in xrange(j-min_dist):
                # Continue only if both samples have the same number of
                # neighbors and more than jsut one neighbor (themselves)
                if nR[j] == nR[k] and nR[j] != 1:
                    l = 0

                    while R[j, l] == R[k, l]:
                        l += 1

                        # If l is equal to the length of the time series at
                        # this point, j and k are twins
                        if l == n_time:
                            # Add the twins to the twin list
                            twins_ik = twins_i[k]

                            twins_ij.append(k)
                            twins_ik.append(j)

                            # Leave the while loop
                            break