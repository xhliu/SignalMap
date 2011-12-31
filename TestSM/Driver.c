#include <tossim.h>
#include <stdlib.h>

enum {
	MAX_LINE_LEN = 100,
	NOISE_RANDOM_NUM = 1000,
};

int main() {
   Tossim* t = new Tossim(NULL);
   Radio* r = t->radio();
   int i, x, y, nodeId;
   double gain, mean, std, noise;

	char filename[] = "2by1_linkgain_1hop.txt";
	int event_run_cnts = 5000;
   	int nodeNum = 2;

   t->addChannel("TestSMC", stdout);
      
   FILE *file = fopen(filename, "r");
   if (file != NULL) {
	  //printf("file %s opened \n", filename);
      char str[MAX_LINE_LEN]; /* or other suitable maximum line size */
 	  char *token;
      while (fgets(str, sizeof(str), file) != NULL) /* read a line */ {
		//split the line
        token = strtok(str," \t");
		//printf("0 token %s \n", token);
		if (strcmp(token, "gain") == 0) {
			token = strtok(NULL," \t");
			x = atoi(token);
			//printf("1 token %s \n", token);
			token = strtok(NULL," \t");
			y = atoi(token);
			//printf("2 token %s \n", token);
			token = strtok(NULL," \t");
			//printf("3 token %s \n", token);
			gain = atof(token);
			//printf("link (%d, %d, %f) added \n", x, y, gain);
			r->add(x, y, gain);
		}

		if (strcmp(token, "noise") == 0) {
			token = strtok(NULL," \t");
			nodeId = atoi(token);
			token = strtok(NULL," \t");
			mean = atof(token);
			token = strtok(NULL," \t");
			std = atof(token);

			Mote* m = t->getNode(nodeId);
			//printf("noise for node %d added, mean = %f, std = %f \n", nodeId, mean, std);
			for (i = 0; i < NOISE_RANDOM_NUM; i++) {
				noise = mean + (drand48() - 0.5) * std * 2;
				m->addNoiseTraceReading((char)noise);
			}
		}
      }
      fclose (file);
   }
   else {
      perror(filename); /* why didn't the file open? */
      return 1;
   }   

   //r->add(0, 1, -54.0);
    
 
   for (i = 0; i < nodeNum; i++) {
     Mote* m = t->getNode(i);
     //global sync
     //m->bootAtTime(0);
     m->bootAtTime(5003 * i + 1); 
     m->createNoiseModel();
   }
 
   for (i = 0; i < event_run_cnts; i++) {
     t->runNextEvent();
   }
 }

