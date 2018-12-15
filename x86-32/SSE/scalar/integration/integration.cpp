#include "integration.h"
#include <math.h>

float NumericalIntegration_CPP( const T1DFunctionPtr ptr, float a, float b, uint32_t steps )
{
	const float diff = b - a;
	const float stepSize = diff / ( float )steps;
	const float halfStepSize = stepSize * 0.5f;

	float integral = 0.0f;
	float error = 0.0f;

	float height1 = ptr( a );

	for( uint32_t i = 1; i <= steps; ++i )
	{
		const float currArg = a + (stepSize * (float)i);
		const float height2 = ptr( currArg );

		const float areaOfTrapezoid = ( height2 + height1 ) * halfStepSize;

		// Kahan summation alg:
		const float areaOfTrapezoidWithError = areaOfTrapezoid + error;
		const float newIntegral = integral + areaOfTrapezoidWithError;
		error = ( areaOfTrapezoidWithError - ( newIntegral - integral ) );
		integral = newIntegral;

		height1 = height2;
	}

	return integral;
}
