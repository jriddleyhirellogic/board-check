/*
 * misc_math.h
 *
 *  Created on: Oct 22, 2025
 *      Author: iboard
 */

#ifndef MISC_MATH_H_
#define MISC_MATH_H_

#define ABS(x) ((x) < 0 ? -(x):(x))
#define SGN(x) (((x) >= 0)? 1 : -1)

#define IP_TO_U32(w,x,y,z) ( ((w & 0xff) << 24) | ((x & 0xff) << 16) | ((y & 0xff) << 8) | (z & 0xff) )


#endif /* MISC_MATH_H_ */
