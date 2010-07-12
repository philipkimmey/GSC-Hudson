install:
	echo "Storing repositories at ~/.hudson_repos"
	mkdir ~/.hudson_repos
	echo "Checking out UR and Genome."
	git clone git@github.com:sakoht/UR.git ~/.hudson_repos/UR
	svn co svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk ~/.hudson_repos/perl_modules
	echo "UR available at ~/.hudson_repos/UR"
	echo "perl_modules available at ~/.hudson_repos/perl_modules"
