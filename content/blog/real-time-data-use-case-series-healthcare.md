+++

date = "2017-11-17"
publishdate = "2017-11-17"
title = "Real-time Data Use Case Series: Healthcare"
author = "Ali Cooley"
author_twitter = "slothware"
author_img = "1"
image = "/img/blog/real-time-use-case-health-header.jpg"
overlay_color = "green" # blue, green, or light

+++

The big data landscape is advancing rapidly, and changing healthcare as we know it.

<!--more-->

As Artificial Intelligence (AI) and Machine Learning (ML) slide out of the shadows and into the limelight, industries must begin to contend with their [many possibilities](https://www.wsj.com/articles/how-artificial-intelligence-will-change-everything-1488856320) and [potential perils](https://www.vanityfair.com/news/2017/03/elon-musk-billion-dollar-crusade-to-stop-ai-space-x). Before these new technologies can be employed and perfected, however, companies must learn to manage the deluge of human and machine-generated data now clogging enterprise-level datastores. 

So far, the it seems the data is winning: [cross-industry studies have shown](https://hbr.org/2017/05/whats-your-data-strategy) that less than 50% of an organization’s structured data are actively used in making decisions, and less than 1% of its unstructured data are analyzed – or even used – at all. This can be [particularly problematic in healthcare](http://www.healthaffairs.org/do/10.1377/hblog20150821.050034/full/), where [approximately 60%](https://insights.datamark.net/white-papers/unstructured-data-in-electronic-health-record-systems-challenges-and-solutions) of valuable patient-care data is “trapped” in unstructured formats.

In this first installment of our industry-level Real-Time Data Series, we will review two existing real-time data use cases that are accelerating the pace of care and delivery breakthroughs in the US Healthcare sector.

![Use case one header](/img/blog/health-use-case-1.jpg)
### Use Case 1: Stopping the Spread of Deadly Iatrogenic Infections

_[Clostridium Difficile (C. diff)](https://www.webmd.com/digestive-disorders/clostridium-difficile-colitis#1)_ is a typically harmless bacteria found throughout the environment, often colonizing the human digestive system with no ill effects. When allowed to grow unchecked, however, it can lead to serious inflammation of the colon, known as colitis, and even death. These growth events are generally rare, as competition with other, beneficial bacteria in our microbiome typically keeps C. diff’s numbers in check. One of the only times an individual is at risk for a C. diff infection is immediately after taking a course of antibiotics, which disrupts the balance of beneficial bacteria in our digestive systems.

C. diff is most often spread iatrogenically within healthcare facilities, as caregivers unknowingly carry it from room to room after touching clothing, sheets, keyboards, and other surfaces. While many hospitals are able to limit the spread of C. diff through standardized sanitation measures, two units at Salem Health hospitals in Portland, Oregon, were experiencing particularly high rates of infection in 2014. 

Rather than go through the standard prevention measures – repeated staff sanitation trainings – Salem [went on the offensive](https://hbr.org/2017/05/whats-your-data-strategy). They deployed their clinical business intelligence (CBI) team to create a real-time reporting system that allowed caregivers across two hospitals, a rehabilitation center, and nine clinics to track and compare C. diff infections across units. They [further revised](http://salemhealth.org/for-healthcare-professionals/common-ground/dec-26-2016/preventing-the-spread-of-c-difficile-part-2) diagnostic algorithms to ensure more efficient diagnosis, closing the gap between symptom onset and appropriate treatment. Within two years, they had dropped off of [Consumer Reports’ list](https://www.consumerreports.org/doctors-hospitals/consumer-reports-names-hospitals-with-high-c-diff-infection-rates/) of hospitals with abnormally high C. diff rates.

![Use case one header](/img/blog/health-use-case-2.jpg)
### Use Case 2: Using Missile Defense Algorithms to Spot Sepsis

[Sepsis](https://www.webmd.com/a-to-z-guides/sepsis-septicemia-blood-infection#1) [kills nearly 40%](https://www.medicinenet.com/sepsis/article.htm) of the 750,000 people who contract it each year, costing hospitals more than $12.5 billion in care costs. Even when it is not fatal, its effects can lead to permanent mental and physical disabilities. The high mortality is due largely to the fast pace of the disease and the difficulties healthcare workers experience in spotting in early on. On the one hand, a patient’s chances of survival drop significantly for every hour they suffer from sepsis. On the other, the disease’s early stages are so similar to the flu that many caregivers do not know to administer the required antibiotic treatments in time. Further complicating the problem, current technologies used to track sepsis are largely ignored by hospital staff due to their exceptionally high error rates.

Working separately, two teams of researchers have identified improved methods to identify sepsis sooner using real-time analytics. The first, out of UC Davis, analyzed patients’ EHRs to determine whether they provided better risk indicators for patients than current methods. They found that three previously unknown indicators – lactate level, blood pressure and respiratory rate – can predict the likelihood of a patient succumbing to the disease with high levels of accuracy. They are currently in the process of creating a customized algorithm for EHR systems that will automatically track these indicators and alert medical staff of a patient’s risk in real time.

The second team, out of Lockheed Martin, has [adapted](https://www.lockheedmartin.com/us/news/features/2014/sepsis-detection.html) the company’s signature ML algorithmic platforms – currently used in missile defense – to accelerate sepsis identification. Rather than focusing on identifying additional indicators, Lockheed Martin focused on improving both the speed and accuracy of sepsis identification. They accomplished this by monitoring continuous, as opposed to minute, changes in patient vital signs and blood work, deploying data analytics to flag sepsis cases. A trial that included more than 4,500 patients concluded that this method correctly identified sepsis cases more than 90% of the time and, on average, about 14 to 16 hours before the conventional approach. Further, it reduced false positives to less than 1%, making diagnosis more reliable in critical care settings.

While both of these interventions are highly disease-specific, their consequences are far reaching for the future of patient health outcomes. In the short term, effectively addressing these persistent health problems will allow caregivers more time and resources to provide better care to more patients. In the long term, these methods can be improved and adapted to additional cases, benefiting countless others in the years to come.

If you have any questions about how Pilosa can help your business unlock your data store for real-time queries, please feel free to [contact us](https://www.pilosa.com/about/#contact).

Ali is the resident Jack of all trades at Pilosa. She likes health and tech porbably more than she should. Find her on Twitter at [@ay_em_see](https://twitter.com/ay_em_see?lang=en).
