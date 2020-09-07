checkParam(){

    #création d'un dossier log qui contient toutes les sorties de fichier du script
    
    logdir="logs"
    if [ ! -d "$logdir" ]
    then
        mkdir $logdir
        
    fi

    html_file=./$logdir/$date"resultat.html"
    cp $template $html_file
#    cp $template $template_temp
    
    #création d'un fichier pour supprimer les logs
    #A FAIRE
    
    
    #analyse des répertoires à traverser

    if [ $# -ne 2 ]
    then
        printf "Voulez vous utiliser les arborescences par défaut (\e[34m\e[1marbo1 \e[0met \e[34m\e[1marbo2\e[0m) pour l'analyse ? \e[1m(\e[32mO\e[39m)\e[0mui / \e[1m(\e[31mN\e[39m)\e[0mon >\n"
        read choix
        while [ "$choix" != "O" ] && [ "$choix" != "N" ]
        do
            echo -e "\e[1m\e[31mVeuillez entrer une lettre valide : \e[39m(\e[32mO\e[39m)ui / (\e[31mN\e[39m)on \e[0m>"
            read choix
        done
        if [ $choix = "O" ]
        then
            rep1="arbo1"
            rep2="arbo2"
            
            local chaine="\e[31m3\e[39m... \e[33m2\e[39m.. \e[32m1\e[39m. \e[1mGO!!!"
            local number
            clear
            for number in $chaine
            do
                echo -e "$number"
                sleep 0.5
                clear
            done
            echo " -- Début de l'opération -- "
        else
            checkRep 1
        fi

    else
        checkRep 0
    fi
    
}

checkRep(){
    #fonction qui test si les repertoires spécifiés existent
    local existRep=$1
    local dir
    
    for ((i=1 ; i<3 ; i++ ))
    do
        if [ $existRep -eq 1 ]  #Si les répertoires n'ont pas été rentrés en param on les read
        then
            echo -e "Entrez le nom du répertoire n°\e[93m\e[1m$i \e[0mà traverser >"
            read dir
        else
            if [ $i -eq 1 ]
            then
                dir=$rep1   #Sinon on test chacun à la suite
            else
                dir=$rep2
            fi
        fi
        
        #test si les dossiers existent / sont accesibles en lecture :
        if [ -f $dir ]
        then
            echo -e "Le nom correspond à un fichier !"
        elif [ ! -r $dir ]
        then
            echo -e "Vous n'avez pas accès en lecture au dossier..."
        fi
        while [ -f $dir ] || [ ! -r $dir ]
        do
            printf "\e[1mVeuillez entrez un nom de DOSSIER \e[4mexistant \e[24m> \e[0m\e[39m"
            read dir
        done

        printf "Le répertoire n°\e[93m\e[1m$i \e[0m(\e[34m\e[1m$dir\e[0m) \e[0mest \e[1m\e[32mvalide \e[0met prêt pour l'analyse !\n\n"
        if [ $i -eq 1 ]
        then
            rep1=$dir
        else
            rep2=$dir
        fi
        sleep 0.5
    done
}



listeFD(){
#fonction qui renvoie la liste des MD5/dossiers dans un fichier et le sauve dans le log
    local type=$1 # 'f':file / 'd':directory
    local dir1=$2
    local dir2=$3
    #fichier clean
    fichierBrut=./$logdir/$date"list_"$type"_"$dir1$dir2.txt
    
    local repTraversee="$dir1 $dir2"
    local dir
    for dir in $repTraversee
    do
        if [ "$dir" = "$dir2" ] #ajoute un séparateur de champ entre arbo1 et arbo2
        then
            echo "- Le repertoire2 ($dir2) contient :" >> $fichierBrut
        fi
        if [ "$dir" = "$dir1" ]
        then
            echo "- Le repertoire1 ($dir1) contient :" >> $fichierBrut
        fi
        local pointeur
        for pointeur in `find $dir -type $type`
        do
            if [ "$type" = "f" ]
            then
                #Si fichier injecte le md5 dans un autre fichier
                md5sum $pointeur >> $fichierBrut
            else
                #Sinon affiche la liste des dossiers
                echo $pointeur >> $fichierBrut
            fi
        done
    done
    #sed -i 's/\s.*$//' $listetxt #équivaut à un cut -d' ' -f1 mais modifie directement le fichier source
    TriFD $type $fichierBrut $dir1 $dir2
}


TriFD(){
    #fonction qui concatène les md5/dossiers en double dans un autre fichier
    local type=$1
    local fichierBrut=$2
    local dir1=$3
    local dir2=$4
    
    local temp=`mktemp TEMP_XXX`
    local fichierTri=`mktemp TEMP_XXX`
    local fichier=`mktemp TEMP_XXX`
    mot="fichiers"
    
    #cleaning du fichier brut
    cat $fichierBrut > $temp #affiche que le md5 /liste des dossier
    sed -i '/-/d' $temp #enlève les lignes informatives
    sort $temp > $fichier
    
    if [ "$type" = "d" ] #on compte le nombre de fichiers différents
    then
        mot="dossiers"
        rm $fichierBrut
         #Shéma du fonctionnement du programme
        
        #Supposons l'arbo suivant :
        #arbo1/
        #   rep1/
        #       fichier1
        #   rep2/
        #       fichier2
        #       sousRep1/
        #           fichier3
        
        #Un dossier est associé au md5 des sous fichiers qu'il contient
        # sousRep1/ = md5sum fichier3
        # rep2 = md5sum fichier contenant md5sum fichier3 + md5sum fichier2 + nom sousRep1/
        
        #trie du fichier en fonction du repertoire le plus "loin"

        local num
        if [ -z "$dir2" ]
        then
            num="2"
        else
            num="3"
        fi
        #trie les fichiers en fonction du nombre de '/' et cut arbo1/2 ou les deux si les 2 sont test
        awk -F/ '{print NF,$0}' $fichier | sort -n | tail -n +$num | cut -d' ' -f2 > $fichierTri

        local ligne
        local pointeur
        local namedir
        local chaine
        > $fichier
        while read ligne
        do
            > $temp
            find $ligne -type f -exec md5sum {} + | awk '{print $1}' | sort | md5sum | awk '{print $1}' >> $temp #ajout du md5 de la liste des md5 de chaque fichier contenu dans un sous dossier
            find $ligne -type d | tail -n +2 | rev | cut -d/ -f1 | rev >> $temp #On ajoute le nom du dossier pour calculer le md5
            #find $ligne -type d | tail -n +2 | cut -d/ -f2-
            chaine=`md5sum $temp | awk '{print $1}'`
            echo "$chaine  $ligne"
        done < $fichierTri >> $fichier
    fi
    local nbFD=`cat $fichier | wc -l`
    cat $fichier | awk '{print $1}' | sort -u > $fichierTri
    local nbdiffFD=`cat $fichierTri | wc -l`
    sort $fichier | cut -d' ' -f1 > $temp
    
    
    
    # VARIABLE MD5 DE TOUS FICHIERS DIFFÉRENTS
    
    tabMD5[$cpt]=`md5sum $temp | cut -d' ' -f1` #stockage des md5 dans un tableau
    if [ "$type" = "f" ] && [ -z "$dir2" ]
    then
        ftemp=$fichierBrut
    fi
    echo "- Le fichier contenant la liste des $mot dans $dir1 a pour md5 : ${tabMD5[$cpt]}" >> $ftemp
    # tabMD5[0] tabMD5[1] tabMD5[2] tabMD5[3]
    # md5file1   md5dir1  md5file2   md5dir2
    
    #Envoie des fichiers différents à l'html
    local nbFD_html
    local nbDiff_html
    if [ -z "$dir2" ]
    then
        if [ $cpt -lt 2 ]
        then
            nbFD_html="%"$type"Tot1"    #si ça correspond au dir 1
            nbDiff_html="%"$type"Diff1"
        else
            nbFD_html="%"$type"Tot2" #si ça correspond au dir 2
            nbDiff_html="%"$type"Diff2"
        fi
    else
        nbFD_html="%"$type"Tot3" #si ça correspond au deux rep
        nbDiff_html="%"$type"Diff3"
    fi
    sed -i "s|$nbFD_html|$nbFD|g" $html_file
# cat $html_file > $template_temp
    
    sed -i "s|$nbDiff_html|$nbdiffFD|g" $html_file
   # cat $html_file > $template_temp
    
    
        
    cpt=$(($cpt+1))
    rm $temp
    if [ -n "$dir2" ]
    then
        local phraseDir2="\e[0met \e[34m\e[1m$dir2"
    fi
    printf "\nIl y a \e[93m\e[1m$nbdiffFD $mot \e[0mdifférents sur \e[93m\e[1m$nbFD \e[0mau total dans \e[34m\e[1m$dir1 $phraseDir2\n\e[0mListe des \e[1m$mot \e[0mdifférents :\n\n"
    nbDiff $fichier $fichierTri $dir1 $dir2
    
    #supprime le fichierBrut si dossier    
}

nbDiff(){

    #fonction qui affiche les fichiers différents et le md5 et l'emplacement des fichiers identiques :
    local fichier=$1
    local fichierTri=$2
    local dir1=$3
    local dir2=$4
    fichierBrutCC=./$logdir/$date"cheminComplet_f_"$dir1"_"$dir2.txt
    local ligne
    local temp=`mktemp TEMP_XXX`
    local temp2=`mktemp TEMP_XXX`

    
  #  awk -F/ '{print NF,$0}' $fichier | sort -n | tail -n +2 | cut -d' ' -f2- > $temp
  #  cat $temp > $fichier
  #  >$temp
    while read ligne
    do
        local nboccur=`grep -c $ligne $fichier`
        #echo "$nboccur : $ligne"


    if [ $nboccur -gt 1 ]
    then
        echo "Le ${mot::-1} ayant comme empreinte md5 $ligne apparait $nboccur fois dans :" >> $temp
        grep $ligne $fichier | cut -d' ' -f3 >> $temp
    else
        firstL=${mot:0:1} #récupère la première lettre du mot pour la passer en maj après
        local chaine=`echo -e "- ${firstL^^}${mot:1:-1} unique : "` #affiche D + 'ossier's
        if [ -z "$dir2" ]
        then
            local FD=`grep $ligne $fichier | rev | cut -d/ -f1 | rev`
        else
            local FD=`grep $ligne $fichier | cut -d' ' -f3`
        fi
        echo $chaine $FD >> $temp2
    fi

    done < $fichierTri
        
    cat $temp $temp2  > $fichierBrutCC
    cat $fichierBrutCC
    
    local listFD_html="%list"$type
    sed ':a;N;$!ba;s/\n/<br>/g' $fichierBrutCC > $temp
    local listFD=`cat $temp`
    if [ -n "$dir2" ]
    then
        listFD_html=$listFD_html"3"
        if [ "$type" = "f" ]
        then
            rm $fichierBrut
        fi
    else
        if [ $cpt -le 2 ]
        then
            listFD_html=$listFD_html"1"
        else
            listFD_html=$listFD_html"2"
        fi
        rm $fichierBrutCC
    fi
    echo $listFD_html
    sed -i "s|$listFD_html|$listFD|g" $html_file
  #  cat $html_file > $template_temp
    
    rm $fichierTri $fichier $temp $temp2
    
}

etatArbo(){
    local dir1=$1
    local dir2=$2
    #echo ${tabMD5[0]} ${tabMD5[1]} ${tabMD5[2]} ${tabMD5[3]}
    local state
    local state_html
    local html_color
    if [ "${tabMD5[0]}" = "${tabMD5[2]}" ] && [ "${tabMD5[1]}" = "${tabMD5[3]}" ]
    then
        state="\e[1m\e[32mIDENTIQUES\e[0m\n"
        state_html="IDENTIQUES"
        html_color="green"
    else
        state="\e[1m\e[31mDIFFERENTES\e[0m\n"
        state_html="DIFFERENTES"
        html_color="red"
    fi
    printf "\nLes deux arborescences \e[34m\e[1m$dir1 \e[0met \e[34m\e[1m$dir2 \e[0msont $state"
    
    #génération des dernières variables dans le template
    
    sed -i "s|%etatArbo|$state_html|g" $html_file
  #  cat $html_file > $template_temp
    sed -i "s|%dir1|$dir1|g" $html_file
  #  cat $html_file > $template_temp
    sed -i "s|%dir2|$dir2|g" $html_file
  #  cat $html_file > $template_temp
    sed -i "s|%clrEtat|$html_color|g" $html_file
    #ouverture page html généré
    xdg-open ./$logdir/$htmlfile
}

template="./html/template.html"
date=`date +%Y%m%d_%H%M%S_`
cpt=0

rep1=$1
rep2=$2
checkParam $rep1 $rep2

listeFD f $rep1
listeFD d $rep1
listeFD f $rep2
listeFD d $rep2
listeFD f $rep1 $rep2
listeFD d $rep1 $rep2
etatArbo $rep1 $rep2
