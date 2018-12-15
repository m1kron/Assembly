#pragma once
#include <stdint.h>

struct MinMaxInfo
{
	int32_t min;
	int32_t max;

	bool operator==( const Info& other )
	{
		return min == other.min && max == other.max;
	}

	bool operator!=( const Info& other )
	{
		return !operator==( other );
	}
};

extern "C" MinMaxInfo FindMinMax_SSE( int32_t* array, uint32_t arraySize );