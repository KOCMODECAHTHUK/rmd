/proc/background()
	set waitfor = FALSE
	return 2

/proc/test()
	return background() + 1
