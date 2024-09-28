// filename: theme.js
const express = require('express');
const { ObjectId } = require('mongodb');

module.exports = function(db) {
    const router = express.Router();

    // Route to fetch theme settings
    router.get('/theme', async (req, res) => {
        const adminId = req.query.admin_id;
        try {
            const theme = await db.collection('theme_management').findOne({ admin_id: new ObjectId(adminId) });
            if (!theme) {
                return res.status(404).json({ message: 'Theme not found' });
            }
            res.status(200).json(theme);
        } catch (error) {
            console.error('Error fetching theme:', error);
            res.status(500).json({ message: 'Internal server error' });
        }
    });
    return router;
};
