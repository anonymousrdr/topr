#include <set>
#include <fstream>

std::set<int> vbbls_set;

extern "C" void cov_tracker(int id)
{
    if(vbbls_set.size() == 0)
    {
        std::ifstream vfile1;
        vfile1.open("vbbls.txt");
        if(!vfile1);
        else
        {
            std::string line = "";
            while(std::getline(vfile1, line)) 
            {
                int vbblid = std::stoi(line);
                vbbls_set.insert(vbblid); //insert old vbbls
            }
        }
        vfile1.close();
    }
    
    int vbbls_sz1 = vbbls_set.size();
    vbbls_set.insert(id); //insert new vbbl
    int vbbls_sz2 = vbbls_set.size();

    if(vbbls_sz1 != vbbls_sz2)
    {
        std::ofstream vfile;
        vfile.open("vbbls.txt", std::ios::app); //append
        vfile <<id<<"\n";
        vfile.close();
    }

    return;
}
