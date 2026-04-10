const express = require('express');
const client = require('prom-client');
const app = express();
const PORT = 4000;
const customers = require('./customers.json');
const fs = require('fs');
const path = require('path');
const customersFilePath = path.join(__dirname, 'customers.json');


app.use(express.json());

app.get('/health', (req, res) => {
   res.status(200).json({ message: 'Health is running OK' });
})

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// List API with search by first_name, last_name, and city with pagination
app.get('/api/customers', (req, res) => {
  const { first_name, last_name, city, page = 1, limit = 10 } = req.query;

  let filteredCustomers = customers;

  if (first_name) {
    filteredCustomers = filteredCustomers.filter(customer =>
      customer.first_name.toLowerCase().includes(first_name.toLowerCase())
    );
  }

  if (last_name) {
    filteredCustomers = filteredCustomers.filter(customer =>
      customer.last_name.toLowerCase().includes(last_name.toLowerCase())
    );
  }

  if (city) {
    filteredCustomers = filteredCustomers.filter(customer =>
      customer.city.toLowerCase() === city.toLowerCase()
    );
  }

  const startIndex = (page - 1) * limit;
  const endIndex = page * limit;
  const paginatedCustomers = filteredCustomers.slice(startIndex, endIndex);

  res.json({
    total: filteredCustomers.length,
    page: parseInt(page),
    limit: parseInt(limit),
    data: paginatedCustomers,
  });
});



app.get('/api/customers/:id', (req, res) => {
  const customerId = parseInt(req.params.id);
  const customer = customers.find(customer => customer.id === customerId);

  if (customer) {
    res.json(customer);
  } else {
    res.status(404).json({ message: 'Customer not found' });
  }
});



app.get('/api/cities', (req, res) => {
  const cityCounts = {};

  customers.forEach(customer => {
    if (cityCounts[customer.city]) {
      cityCounts[customer.city]++;
    } else {
      cityCounts[customer.city] = 1;
    }
  });

  res.json(cityCounts);
});


app.post('/api/customers', (req, res) => {
  const newCustomer = req.body;

  if (!newCustomer.first_name || !newCustomer.last_name || !newCustomer.city || !newCustomer.company) {
    return res.status(400).json({ message: 'All fields are required' });
  }

  const existingCity = customers.find(customer => customer.city === newCustomer.city);
  const existingCompany = customers.find(customer => customer.company === newCustomer.company);

  if (!existingCity || !existingCompany) {
    return res.status(400).json({ message: 'City or company does not exist' });
  }

  newCustomer.id = customers.length + 1;
  customers.push(newCustomer);

  // Update JSON file with the new data
  fs.writeFile(customersFilePath, JSON.stringify(customers), err => {
    if (err) {
      return res.status(500).json({ message: 'Failed to update data' });
    }
    res.status(201).json(newCustomer);
  });
});


app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
