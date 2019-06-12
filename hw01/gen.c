// ======================================================================
// 201511061 정창현 gen.c 소스코드
// ======================================================================
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
// ======================================================================
int numOfAlphabet;
int lwl;// length of word
void gen(char* str, int n, char* argv[])
{
        if (n == 0) printf("%s\n", str);
        else
        {
                for (int i = 1; i <= numOfAlphabet; i++)
                {
			char* word;
			word = (char*)malloc(sizeof(char)*(strlen(str))+1);
			strcpy(word, str);
			strcat(word, argv[i]);
			gen(word, n - 1, argv);
		}
	}
};

// ======================================================================
int main(int argc, char* argv[])
{
	numOfAlphabet = argc - 2; // 입력 문자 개수
	lwl = atoi(argv[argc - 1]);// word의 크기

	if (numOfAlphabet < 2)
	{
		printf("Usage: gen symbol_list n\n");
		return -1;
	}


	if (numOfAlphabet >= 2)
	{

		for (int i = 0; i <= lwl; i++)
		{
			gen("", i, argv);
		}
		return 0;
	}
}
