install:
    echo "Storing repositories at ~/.hudson_repos"
    mkdir ~/.hudson_repos
    echo "Cloning UR"
    git clone git@github.com:sakoht/UR.git ~/.hudson_repos/UR
    echo "Cloning genome"
    git clone ssh://git/srv/git/workflow.git ~/.hudson_repos/genome
    echo "Cloning workflow"
    git clone ssh://git/srv/git/workflow.git ~/.hudson_repos/workflow
    echo "UR, genome and workflow available at ~/.hudson_repos/    
