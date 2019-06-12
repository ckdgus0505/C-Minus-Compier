#include<stdio.h>
#include<stdlib.h>
#include<string.h>
typedef struct queue
{
	int front;
	int back;
	char* arr[5000];
} Queue;

int main(int argc, char* argv[])
{
	int numOfCharacters;
	int sizeOfWord;
	numOfCharacters = argc - 2; // 입력 문자 개수
	sizeOfWord = atoi(argv[argc-1]);// word의 크기

	Queue q1;
	q1.front = 0;
	q1.back = 1;
	q1.arr[0] = "";
	Queue q2;
	q2.front = 0;
	q2.back = 0;

	if (numOfCharacters < 2)
	{
		printf("Usage: gen symbol_list n\n");
		return 0;
	}


	if (numOfCharacters >= 2)
	{
		printf("%s\n", q1.arr[q1.front]);
		for (int i = 0; i < sizeOfWord; i++)
		{
			if (i % 2 == 0)
			{
//				for(int w = q1.front; w < q1.back; w++)
//				{
//					printf("%s\n", q1.arr[w]);
//				}
				while (q1.front != q1.back)
				{
					for (int j = 1; j <= numOfCharacters; j++)
					{
						char* ptr = NULL;
						ptr = (char*)malloc(sizeof(char)*strlen(q1.arr[q1.front]) + 1);
						strcpy(ptr, q1.arr[q1.front]);
						strcat(ptr, argv[j]);
						q2.arr[q2.back] = ptr;
						q2.back = (q2.back+1)%5000;
					}
					q1.front = (q1.front + 1) % 5000;
				}
				for(int w = q2.front; w < q2.back; w++)
				{
					printf("%s\n", q2.arr[w]);
				}
			}
			else if (i % 2 == 1)
			{
//				for(int w = q2.front; w < q2.back; w++)
//				{
//					printf("%s\n", q2.arr[w]);
//				}
				while (q2.front != q2.back)
				{
					for (int j = 1; j <= numOfCharacters; j++)
					{
						char* ptr = NULL;
						ptr = (char*)malloc(sizeof(char)*strlen(q2.arr[q2.front]) + 1);
						strcpy(ptr, q2.arr[q2.front]);
						strcat(ptr, argv[j]);
						q1.arr[q1.back] = ptr;
						q1.back = (q1.back+1)%5000;
					}
					q2.front = (q2.front + 1) % 5000;
				}
				for(int w = q1.front; w < q1.back; w++)
				{
					printf("%s\n", q1.arr[w]);
				}
			}
		}
	}
	return 0;
}
