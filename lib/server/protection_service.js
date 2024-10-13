const express = require('express');
const { ObjectId } = require('mongodb');
const router = express.Router();

module.exports = (db) => {
    // Route to get remaining time for a specific child
    router.get('/protection/:childId', async (req, res) => {
        const { childId } = req.params;
        console.log(`[PROTECTION SERVICE] Received childId: ${childId}`);

        try {
            const childIdQuery = ObjectId.isValid(childId) ? new ObjectId(childId) : null;

            if (!childIdQuery) {
                return res.status(400).json({ message: 'Invalid childId' });
            }

            const remainingTimeDoc = await db.collection('remaining_time').findOne({ child_id: childIdQuery });

            if (!remainingTimeDoc) {
                return res.status(404).json({ message: 'No remaining time found for this child.' });
            }

            const timeSlots = remainingTimeDoc.time_slots;

            if (!timeSlots || timeSlots.length === 0) {
                return res.status(404).json({ message: 'No time slots available for this child.' });
            }

            const remainingTime = timeSlots[0]?.remaining_time || 0;

            return res.status(200).json({
                child_id: childIdQuery,
                remaining_time: remainingTime,
                time_slots: timeSlots.map((slot, index) => ({
                    slot_number: index + 1,
                    start_time: slot.start_time,
                    end_time: slot.end_time,
                    remaining_time: slot.remaining_time,
                })),
            });
        } catch (error) {
            console.error('[PROTECTION SERVICE] Error:', error);
            return res.status(500).json({ message: 'Failed to fetch remaining time.', error });
        }
    });

    return router; // Return the router
};



/*const express = require('express');
const { ObjectId } = require('mongodb');
const router = express.Router();

module.exports = (db) => {
    // Route to get remaining time for a specific child
    router.get('/protection/:childId', async (req, res) => {
        const { childId } = req.params;
        console.log(`[PROTECTION SERVICE] Received childId: ${childId}`);

        try {
            const childIdQuery = ObjectId.isValid(childId) ? new ObjectId(childId) : null;

            if (!childIdQuery) {
                return res.status(400).json({ message: 'Invalid childId' });
            }

            const remainingTimeDoc = await db.collection('remaining_time').findOne({ child_id: childIdQuery });

            if (!remainingTimeDoc) {
                return res.status(404).json({ message: 'No remaining time found for this child.' });
            }

            const timeSlots = remainingTimeDoc.time_slots;
            if (!timeSlots || timeSlots.length === 0) {
                return res.status(404).json({ message: 'No time slots available for this child.' });
            }

            const remainingTime = timeSlots[0]?.remaining_time || 0;

            return res.status(200).json({
                child_id: childIdQuery,
                remaining_time: remainingTime,
            });
        } catch (error) {
            console.error('[PROTECTION SERVICE] Error:', error);
            return res.status(500).json({ message: 'Failed to fetch remaining time.', error });
        }
    });

    return router;
};
*/

/*const express = require('express');
const { ObjectId } = require('mongodb');
const router = express.Router();

module.exports = (db) => {
    // Route to get remaining time for a specific child
    router.get('/protection/:childId', async (req, res) => {
        const { childId } = req.params;
        console.log(`[PROTECTION SERVICE] Received childId: ${childId}`);  // Log incoming childId for debugging

        try {
            // Ensure the childId is converted to ObjectId if valid
            const childIdQuery = ObjectId.isValid(childId) ? new ObjectId(childId) : null;

            if (!childIdQuery) {
                console.log(`[PROTECTION SERVICE] Invalid childId: ${childId}`);
                return res.status(400).json({ message: 'Invalid childId' });
            }

            console.log(`[PROTECTION SERVICE] Converted childId: ${childIdQuery}`);  // Log the converted childId

            // Fetch the document from the collection
            const remainingTimeDoc = await db.collection('remaining_time').findOne({ child_id: childIdQuery });

            if (!remainingTimeDoc) {
                console.log(`[PROTECTION SERVICE] No document found for childId: ${childIdQuery}`);
                return res.status(404).json({ message: 'No remaining time found for this child.' });
            }

            console.log(`[PROTECTION SERVICE] Found document: ${JSON.stringify(remainingTimeDoc)}`);

            // Log the structure of the time slots if they exist
            const timeSlots = remainingTimeDoc.time_slots;
            if (!timeSlots || timeSlots.length === 0) {
                console.log(`[PROTECTION SERVICE] No time slots available for childId: ${childIdQuery}`);
                return res.status(404).json({ message: 'No time slots available for this child.' });
            }

            // Fetch and log the first time slot's remaining time
            const remainingTime = timeSlots[0]?.remaining_time || 0;
            console.log(`[PROTECTION SERVICE] Remaining time found: ${remainingTime} for childId: ${childIdQuery}`);

            // Return the remaining time
            return res.status(200).json({
                child_id: childIdQuery,
                remaining_time: remainingTime,
            });
        } catch (error) {
            console.error('[PROTECTION SERVICE] Error fetching remaining time:', error);
            return res.status(500).json({ message: 'Failed to fetch remaining time.', error });
        }
    });

    return router;
};
*/