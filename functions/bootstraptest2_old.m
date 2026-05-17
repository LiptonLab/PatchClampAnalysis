function P_value=bootstraptest2(SAMPLE1,SAMPLE2,nRepeat)
    nDataset=size(SAMPLE1,2);
    if size(SAMPLE1,1)>=2
        for ii=1:nDataset
            sampledata1=SAMPLE1(:,ii);
            sampledata2=SAMPLE2(:,ii);
            %compare mean value of 2 samples
            bootmean1=mean(bootstrp(nRepeat,@(a)[a],sampledata1),2);
            %•½‹Ï’l?i2ŽŸŒ³•ûŒü?j
            bootmean2=mean(bootstrp(nRepeat,@(a)[a],sampledata2),2);%•½‹Ï’l?i2ŽŸŒ³•ûŒü?j
            parentdata=bootmean1-bootmean2;
            ref_value=0;%?·‚ª‚O‚Å‚ ‚é?‡ˆÊ‚ð’T‚·
            totaldata=[parentdata;ref_value];
            Sort=sort(totaldata);
            ranking=median(find(Sort==ref_value));%?‡ˆÊ‚ª•¡?”‚ ‚Á‚½‚ç’†ŠÔ’l
            p=min(ranking/(nRepeat+1),(nRepeat+1-ranking+1)/(nRepeat+1));%‚P”Ô‚©n”Ô‚¾‚Á‚½‚ç1/n‚É‚È‚é—l‚É?B
            P_value(1,ii)=p*2;
        end
    else
        P_value = -1;
    end
end