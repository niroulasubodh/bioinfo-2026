# How to Collaborate 

I am collaborating with Kny-Le.

## Forking and Cloning the Repository 

```git clone https://github.com/niroulasubodh/BMMB852_KL.git``` 

## Verify that the code is not doing something dangerous using an AI assistant (Codex)

**Prompt:** \
*Please audit the cloned @Makefile for security risks before I run it. Check for Arbitrary or malicious network activity, Dangerous file operations, Hidden or obfuscated code, and suspicious auto-execution targets. Give me a clear verdict (Safe / Suspicious / Malicious), summarize any potential threats, and list the exact commands that require caution.*

**Response:** \
*Verdict: Safe*

## Does the ```README.md``` make it clear how to run the code and what the outcomes are?
Yes, the structure in ```README.md``` (Makefile → download → index → IGV → questions) is logical and well-organized. 


## Verify that the results are reproducible. Does the code do what the author says it does?
 Yes, the results are reproducible, and the code does what the author claims. One small confusion I got from the ```README``` file is that the ```Makefile``` already renames and makes indices itself. However, the ```README``` file mentions renaming and making indices again. 

## AI agent comparison 

**Prompt:** \
*Compare the Week 02 assignment solutions at these two links:
https://github.com/Kny-Le/BMMB852_KL/tree/main/Week02
https://github.com/niroulasubodh/bioinfo-2026/tree/main/week02 
In a few sentences, compare their approaches and state which one is better.*

**Response**\
*Kny-Le’s solution is more complete analytically, including genome statistics, BUSCO assessment, six reading frames, and strand visualization; Subodh’s solution has a cleaner, better-organized Makefile with proper GFF sorting and clearer figures.
Overall, Kny-Le’s submission better fulfills all assignment questions, although Subodh’s computational workflow is more reproducible and technically polished.* 

## Changes in ```README``` and ```Makefile```
First, I added comments to the ```Makefile``` to make clear that it also renames files and generates indices. I then updated the ```README``` to include the corrected Makefile code, since the version originally shown in the ```README``` didn't match the actual ```Makefile``` being used. I replaced it with the up-to-date version along with its actual output, and removed the now-obsolete "rename files" and "make indices" instructions from the ```README```, since those steps are now handled automatically by ```Makefile```. 

[**Click Here to View the Pull Request**](https://github.com/Kny-Le/BMMB852_KL/pull/1)
