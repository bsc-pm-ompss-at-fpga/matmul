#if defined(USE_DOUBLE)
    //typedef double  elem_t;
    #define elem_t double
    #define ELEM_T_STR  "double"
#elif defined(USE_HALF)
    //typedef half    elem_t;
    #define elem_t half
    #include <hls_half.h>
    #define ELEM_T_STR  "half"
#else
    //typedef float      elem_t;
    #define elem_t float
    #define ELEM_T_STR "float"
#endif
