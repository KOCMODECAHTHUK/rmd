/proc/early()
	return LATER

#define LATER 1
#define EARLY 2
#define SELF SELF
#define CALL(x) x

/proc/late()
	return EARLY + SELF + CALL
