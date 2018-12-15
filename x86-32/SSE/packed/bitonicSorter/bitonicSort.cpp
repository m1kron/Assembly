#include "bitonicSort.h"
#include <functional>

/////////////////////////////////////////////////////////////////////////////////////
// Time complexity: O(1)
template< typename TComparator >
void SortTwo_CPP( int32_t* a, int32_t* b, const TComparator& comparator )
{
	if( comparator( *b, *a ) )
		std::swap( *b, *a );
}

/////////////////////////////////////////////////////////////////////////////////////
// Time complexity: O( n*log(n) )
template< typename TComparator >
void BitonicSortImpl_CPP( int32_t* array, uint32_t size, const TComparator& comparator )
{
	if( size == 1 )
		return;

	uint32_t currSize = size / 2;
	for( uint32_t i = 0; i < currSize; ++i )
		SortTwo_CPP( array + i, array + i + currSize, comparator );

	BitonicSortImpl_CPP( array, currSize, comparator );
	BitonicSortImpl_CPP( array + currSize, currSize, comparator );
}

/////////////////////////////////////////////////////////////////////////////////////
// Time complexity: O( n*log^2(n) )
bool BitonicSort_CPP( int32_t* array, uint32_t size )
{
	if( ( size & ( size - 1 ) ) != 0 )
		return false; // size has to be power of 2.

	for( uint32_t step = 2; step < size; step *= 2 )
	{
		const uint32_t iterations = size / step;
		for( uint32_t i = 0; i < iterations; i+=2 )
		{
			BitonicSortImpl_CPP( array + i * step, step, std::less<int32_t>() );
			BitonicSortImpl_CPP( array + ( i + 1 ) * step, step, std::greater<int32_t>() );
		}
	}

	BitonicSortImpl_CPP( array, size, std::less<int32_t>() );

	return true;
}

// Those functions are defined in bitonicSort_.asm
extern "C" void MakeInitialBitonicSequence_SSE_( int32_t* array, uint32_t size );
extern "C" void SortBitonicSeqIncreasing_SSE_( int32_t* array, uint32_t size );
extern "C" void SortBitonicSeqDecreasing_SSE_( int32_t* array, uint32_t size );

/////////////////////////////////////////////////////////////////////////////////////
// Time complexity: O( n*log^2(n) )
bool BitonicSort_SSE( int32_t* array, uint32_t size )
{
	if( ( size & ( size - 1 ) ) != 0 )
		return false; // size has to be power of 2.

	if( ( (size_t)array & 15 ) != 0 )
		return false; // numbersPtr have to be aligned to 16 byte.

	if( size < 8 )
		return false; // ASM code have assumptions about the size of the input and it won't work for sizes less then 8 at this moment.

	MakeInitialBitonicSequence_SSE_( array, size );

	// Log(n) steps.
	for( uint32_t step = 8; step < size; step *= 2 )
	{
		// Each calls SortBitonicSeq for all n elements.
		const uint32_t iterations = size / step;
		for( uint32_t i = 0; i < iterations; i += 2 )
		{
			SortBitonicSeqIncreasing_SSE_( array + i * step, step );
			SortBitonicSeqDecreasing_SSE_( array + ( i + 1 ) * step, step );
		}
	}

	SortBitonicSeqIncreasing_SSE_( array, size );

	return true;
}
