# Citrix-Health-Check
First stab at daily email for citrix health.  I was asked to set something up so my team had a visual into citrix.  This is a work in progress, so for now it's ugly but does the job.  This does the following...<br>

Connect to the ADC controller, query the status of the storefront servers and the age of SSL certs.<br>
![image](https://user-images.githubusercontent.com/16924934/206466831-ce6eb313-6420-4742-8be3-e217d8b0a88d.png)

  
![image](https://user-images.githubusercontent.com/16924934/206469005-ea4159f8-6a54-48bb-af84-8336cd851e37.png)


<br>Connect to KMS server and check RDS device CALs<br>
![image](https://user-images.githubusercontent.com/16924934/206467566-416856d6-04b5-4fc2-824e-4f35999814f0.png)


Check status of machine catalogs<br>
![image](https://user-images.githubusercontent.com/16924934/206467706-d74d42a8-ae5c-426a-9d68-5052e47d155e.png)

  
Check status of individual worker servers<br>
![image](https://user-images.githubusercontent.com/16924934/206468284-184d5a22-18b9-47b6-b9fe-0ac4ef504534.png)


Checks session count for previous day<br>
![image](https://user-images.githubusercontent.com/16924934/206466491-346d50db-f1d1-4930-86bb-9a03cdbb5a17.png)
